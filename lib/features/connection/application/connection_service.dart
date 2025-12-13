import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'dart:math';

import 'package:local_sync/src/rust/api/identity.dart';
import 'package:local_sync/src/rust/api/trust.dart';
import 'package:local_sync/features/transport/message_router.dart';
import 'package:local_sync/features/transport/transport_protocol.dart';
import 'package:local_sync/features/discovery/domain/discovered_peer.dart';

typedef TrustValidator = bool Function(String fingerprint);

/// A helper to reassemble fragmented TCP streams into complete messages.
///
/// TCP is a stream protocol, so a single "message" might arrive in multiple chunks,
/// or multiple messages might arrive in a single chunk. This class buffers bytes
/// until a full length-prefixed frame is received.
class PacketReassembler {
  final BytesBuilder _buffer = BytesBuilder();
  int? _expectedLength;

  /// Feeds a chunk of data into the buffer and returns any complete messages
  /// that are now available.
  List<Uint8List> processChunk(Uint8List chunk) {
    _buffer.add(chunk);
    final List<Uint8List> messages = [];

    while (true) {
      // 1. Do we have enough bytes to read the length header? (4 bytes)
      if (_expectedLength == null) {
        if (_buffer.length < 4) break;
        // Read the first 4 bytes as the 32-bit integer length
        final bufferBytes = _buffer.toBytes();
        _expectedLength = ByteData.sublistView(bufferBytes, 0, 4).getUint32(0);
        // Remove the 4 length bytes from the buffer
        _buffer.clear();
        _buffer.add(bufferBytes.sublist(4));
      }

      // 2. Do we have the full message body?
      if (_expectedLength != null) {
        if (_buffer.length < _expectedLength!) break;
        // We have a full message! Extract it.
        final bufferBytes = _buffer.toBytes();
        messages.add(bufferBytes.sublist(0, _expectedLength!));
        // Put the remaining bytes (if any) back into the buffer
        final remaining = bufferBytes.sublist(_expectedLength!);
        _buffer.clear();
        _buffer.add(remaining);

        // Reset expectations for the next message
        _expectedLength = null;
      }
    }
    return messages;
  }
}

class ConnectionService {
  final NetworkIdentity _identity;
  final TrustValidator _isTrusted;
  final MessageRouter _messageRouter;
  SecureServerSocket? _server;
  final SecurityContext _securityContext;
  int _listeningPort = 0;
  int get listeningPort => _listeningPort;

  /// A map of all active, trusted connections.
  /// We store the [SecureSocket] to send data and the [PacketReassembler]
  /// to handle incoming fragmented data.
  final Map<String, MapEntry<SecureSocket, PacketReassembler>>
  _activeConnections = {};

  // Handshake State
  final Map<SecureSocket, Uint8List> _pendingChallenges = {};
  final Map<SecureSocket, String> _pendingIncomingAuth = {};
  final Map<SecureSocket, String> _pendingOutgoingAuth = {};

  ConnectionService._(
    this._identity,
    this._isTrusted,
    this._messageRouter,
    this._securityContext,
  );

  static Future<ConnectionService> create({
    required NetworkIdentity identity,
    required TrustValidator isTrusted,
    required MessageRouter messageRouter,
  }) async {
    final tlsConfig = await generateEphemeralCert();
    final context = SecurityContext(withTrustedRoots: true);
    // 1. Load our Identity (Certificate Chain + Private Key)
    // This is used by the Server to prove its identity to clients.
    context.useCertificateChainBytes(utf8.encode(tlsConfig.certPem));
    context.usePrivateKeyBytes(utf8.encode(tlsConfig.keyPem));

    return ConnectionService._(identity, isTrusted, messageRouter, context);
  }

  Future<void> startServer() async {
    if (_server != null) return;

    int retryCount = 0;
    const maxRetries = 3;

    while (retryCount < maxRetries) {
      try {
        _server = await SecureServerSocket.bind(
          InternetAddress.anyIPv4,
          0,
          _securityContext,
          requestClientCertificate: false,
          shared: true,
        );
        _listeningPort = _server!.port;

        _server?.listen(
          (SecureSocket socket) => _handleSocketStream(socket),
          onError: (e) => print("❌ Server Socket Error: $e"),
          onDone: () => print("❌ Server Socket Closed"),
        );
        return;
      } catch (e) {
        print("⚠️ Bind attempt failed: $e");
        retryCount++;
        if (retryCount >= maxRetries) {
          print(
            "🔥 CRITICAL: Failed to bind port $listeningPort after $maxRetries attempts.",
          );
        } else {
          await Future.delayed(Duration(milliseconds: 1000 * retryCount));
        }
      }
    }
  }

  void _handleSocketStream(SecureSocket socket) {
    final reassembler = PacketReassembler();

    socket.listen(
      (data) {
        final messages = reassembler.processChunk(Uint8List.fromList(data));
        for (final msg in messages) {
          _processMessage(socket, msg);
        }
      },
      onError: (e) {
        print("⚠️ Socket Error (${socket.remoteAddress.address}): $e");
        _cleanupSocket(socket);
      },
      onDone: () {
        _cleanupSocket(socket);
      },
    );
  }

  Future<void> _processMessage(SecureSocket socket, Uint8List message) async {
    if (message.isEmpty) return;
    final typeByte = message[0];
    final type = MessageType.values.firstWhere(
      (e) => e.value == typeByte,
      orElse: () => MessageType.unknown,
    );
    final payload = message.sublist(1);

    // --- HANDSHAKE LOGIC ---

    if (type == MessageType.authHello) {
      final peerId = utf8.decode(payload);

      _pendingIncomingAuth[socket] = peerId;
      final challenge = _generateRandomChallenge();
      _pendingChallenges[socket] = challenge;
      _sendFrame(socket, MessageType.authChallenge, challenge);
      return;
    }

    if (type == MessageType.authChallenge) {
      // Step A: Sign the random challenge (Proves we own our Node ID)
      final challengeSignature = await signChallenge(
        identity: _identity,
        challenge: payload,
      );

      // Step B: Get our Cluster Proof (Proves we own the Master Key)
      final clusterProof = await _identity.getClusterProof();

      // Step C: Combine them.
      // Signature is always 64 bytes (Ed25519). Proof is 64 bytes.
      final combinedPayload = Uint8List.fromList([
        ...challengeSignature,
        ...clusterProof,
      ]);

      _sendFrame(socket, MessageType.authResponse, combinedPayload);
      return;
    }

    if (type == MessageType.authResponse) {
      final challenge = _pendingChallenges[socket];
      final peerId = _pendingIncomingAuth[socket];

      if (challenge == null || peerId == null) {
        /* Error handling */
        return;
      }

      // We expect at least 64 bytes (Signature).
      // If 128 bytes, it includes Cluster Proof.
      if (payload.length < 64) {
        /* Error */
        return;
      }

      final signatureBytes = payload.sublist(0, 64);
      final hasProof = payload.length >= 128;

      // 1. Verify Node Ownership (Challenge Signature)
      final isSignatureValid = await verifyResponse(
        publicKeyHex: peerId,
        challenge: challenge,
        signatureBytes: signatureBytes,
      );

      // 2. Check Explicit Trust (Database)
      final isExplicitlyTrusted = _isTrusted(peerId);

      // 3. Check Cluster Trust (Auto-Connect)
      bool isClusterMember = false;
      if (hasProof) {
        final proofBytes = payload.sublist(64, 128);
        isClusterMember = await _identity.verifyClusterMembership(
          peerNodeIdHex: peerId,
          proof: proofBytes,
        );
      }

      final isAuthorized =
          isSignatureValid && (isExplicitlyTrusted || isClusterMember);

      if (isAuthorized) {
        _activeConnections[peerId] = MapEntry(socket, PacketReassembler());
        _pendingChallenges.remove(socket);
        _pendingIncomingAuth.remove(socket);

        _sendFrame(socket, MessageType.authAck, []);
      } else {
        // Received non-auth packet while unauthenticated
        socket.destroy();
      }
      return;
    }

    // Handle Auth Ack (Client Side)
    if (type == MessageType.authAck) {
      final peerId = _pendingOutgoingAuth[socket];
      if (peerId != null) {
        _activeConnections[peerId] = MapEntry(socket, PacketReassembler());
        _pendingOutgoingAuth.remove(socket);
      }
      return;
    }

    // --- DATA LOGIC (Authenticated Only) ---
    final entry = _activeConnections.entries.firstWhere(
      (e) => e.value.key == socket,
      orElse: () => MapEntry('', MapEntry(socket, PacketReassembler())),
    );

    if (entry.key.isNotEmpty) {
      _messageRouter.handleData(message, entry.key);
    }
  }

  Future<void> connectToPeer(DiscoveredPeer peer) async {
    if (_activeConnections.containsKey(peer.id)) {
      return;
    }

    try {
      final socket = await SecureSocket.connect(
        peer.host,
        peer.port,
        onBadCertificate: (_) => true,
        timeout: const Duration(seconds: 5),
      );

      // NEW: Track this socket as an outgoing attempt to this Peer ID
      _pendingOutgoingAuth[socket] = peer.id;

      _handleSocketStream(socket);

      final myId = await _identity.publicId();
      _sendFrame(socket, MessageType.authHello, utf8.encode(myId));
    } catch (e) {
      print("🔥 Connect Error (${peer.host}): $e");
    }
  }

  void _sendFrame(SecureSocket socket, MessageType type, List<int> payload) {
    final builder = BytesBuilder();
    final totalLen = 1 + payload.length;

    final lenData = ByteData(4)..setUint32(0, totalLen);
    builder.add(lenData.buffer.asUint8List());
    builder.addByte(type.value);
    builder.add(payload);

    socket.add(builder.toBytes());
  }

  Uint8List _generateRandomChallenge() {
    final rnd = Random.secure();
    return Uint8List.fromList(List.generate(32, (_) => rnd.nextInt(256)));
  }

  void _cleanupSocket(SecureSocket socket) {
    _activeConnections.removeWhere((key, value) => value.key == socket);
    _pendingChallenges.remove(socket);
    _pendingIncomingAuth.remove(socket);
    _pendingOutgoingAuth.remove(socket);
    socket.destroy();
  }

  Future<void> broadcastStream({
    required Uint8List header,
    required Stream<List<int>> Function() dataStreamFactory,
    required int totalSize,
    void Function(int sent)? onProgress,
  }) async {
    if (_activeConnections.isEmpty) {
      // Don't return, maybe we want to queue?
      // For now, let's just return to avoid crashes.
      return;
    }

    final List<String> disconnected = [];
    final List<Future<void>> tasks = [];
    int bytesSentSoFar = header.length;

    for (final entry in _activeConnections.entries) {
      final fp = entry.key;
      final socket = entry.value.key;
      tasks.add(
        Future(() async {
          try {
            socket.add(header);
            Stream<List<int>> stream = dataStreamFactory();
            bool isPrimary = tasks.isEmpty;
            stream = stream.map((chunk) {
              if (isPrimary) {
                bytesSentSoFar += chunk.length;
                onProgress?.call(bytesSentSoFar);
              }
              return chunk;
            });
            await socket.addStream(stream);
            await socket.flush();
          } catch (e) {
            disconnected.add(fp);
          }
        }),
      );
    }
    await Future.wait(tasks);
    for (var fp in disconnected) {
      if (_activeConnections.containsKey(fp)) {
        _cleanupSocket(_activeConnections[fp]!.key);
      }
    }
  }

  void dispose() {
    _server?.close();
    _server = null;
    for (var e in _activeConnections.values) {
      e.key.destroy();
    }
    _activeConnections.clear();
  }
}
