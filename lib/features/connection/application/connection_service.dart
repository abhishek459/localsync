import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:basic_utils/basic_utils.dart';
import 'package:local_sync/features/discovery/domain/discovered_peer.dart';
import 'package:local_sync/features/identity/domain/device_identity.dart';
import 'package:local_sync/features/transport/message_router.dart';
import 'package:local_sync/features/transport/transport_protocol.dart';

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
        if (_buffer.length < 4) {
          break; // Not enough data yet to know the length
        }
        // Read the first 4 bytes as the 32-bit integer length
        final bufferBytes = _buffer.toBytes();
        final lengthHeader = ByteData.sublistView(bufferBytes, 0, 4);
        _expectedLength = lengthHeader.getUint32(0);

        // Remove the 4 length bytes from the buffer
        _buffer.clear();
        _buffer.add(bufferBytes.sublist(4));
      }

      // 2. Do we have the full message body?
      if (_expectedLength != null) {
        if (_buffer.length < _expectedLength!) {
          break; // Still waiting for the rest of the payload
        }

        // We have a full message! Extract it.
        final bufferBytes = _buffer.toBytes();
        final message = bufferBytes.sublist(0, _expectedLength!);
        messages.add(message);

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
  final DeviceIdentity _identity;
  final TrustValidator _isTrusted;
  final MessageRouter _messageRouter;
  SecureServerSocket? _server;
  final SecurityContext _securityContext;

  /// A map of all active, trusted connections.
  /// We store the [SecureSocket] to send data and the [PacketReassembler]
  /// to handle incoming fragmented data.
  final Map<String, MapEntry<SecureSocket, PacketReassembler>>
  _activeConnections = {};

  /// Keeps track of sockets that have connected but haven't sent their identity yet.
  final Set<SecureSocket> _unauthenticatedSockets = {};

  ConnectionService({
    required DeviceIdentity identity,
    required TrustValidator isTrusted,
    required MessageRouter messageRouter,
  }) : _identity = identity,
       _isTrusted = isTrusted,
       _messageRouter = messageRouter,
       _securityContext = SecurityContext() {
    try {
      final certBytes = Uint8List.fromList(
        utf8.encode(_identity.certificate!.plain!),
      );
      final keyBytes = Uint8List.fromList(
        utf8.encode(_identity.privateKeyPem!),
      );

      // 1. Load our Identity (Certificate Chain + Private Key)
      // This is used by the Server to prove its identity to clients.
      _securityContext.useCertificateChainBytes(certBytes);
      _securityContext.usePrivateKeyBytes(keyBytes);
    } catch (e) {
      // Log error loading security context if necessary
      print('Error loading security context: $e');
    }
  }

  /// Helper to calculate fingerprint from a raw PEM string
  String _getFingerprintFromCertPem(String pem) {
    try {
      final certData = X509Utils.x509CertificateFromPem(pem);
      return certData.sha256Thumbprint!.replaceAll(':', '').toLowerCase();
    } catch (e) {
      return '';
    }
  }

  /// Helper to calculate fingerprint from a TLS Certificate object
  String _getFingerprintFromCert(X509Certificate cert) {
    return _getFingerprintFromCertPem(cert.pem);
  }

  Future<void> startServer() async {
    if (_server != null) return;

    try {
      _server = await SecureServerSocket.bind(
        InternetAddress.anyIPv4,
        45678,
        _securityContext,
        requireClientCertificate: false,
        requestClientCertificate: false,
      );

      _server?.listen(
        (SecureSocket socket) {
          _handleSocketStream(socket);
        },
        onError: (error) {
          print('Server Listen Error: $error');
        },
      );
    } catch (e) {
      print('Failed to start server: $e');
    }
  }

  /// Unified handler for managing the socket lifecycle, reassembly, and auth state.
  void _handleSocketStream(SecureSocket socket, {String? preKnownFingerprint}) {
    bool isAuthenticated = preKnownFingerprint != null;
    String? fingerprint = preKnownFingerprint;

    // Create a reassembler specific to this socket stream
    final reassembler = PacketReassembler();

    if (isAuthenticated) {
      _activeConnections[fingerprint!] = MapEntry(socket, reassembler);
    } else {
      _unauthenticatedSockets.add(socket);

      // Security: Enforce a 10-second timeout for authentication.
      Future.delayed(const Duration(seconds: 10), () {
        if (!isAuthenticated && _unauthenticatedSockets.contains(socket)) {
          socket.destroy();
          _unauthenticatedSockets.remove(socket);
        }
      });
    }

    socket.listen(
      (List<int> data) {
        if (data.isEmpty) return;
        final chunk = Uint8List.fromList(data);

        // Feed the raw chunk into the reassembler
        final messages = reassembler.processChunk(chunk);

        // Process all complete messages found in this chunk
        for (final message in messages) {
          _processCompleteMessage(
            socket,
            reassembler,
            message,
            isAuthenticated,
            fingerprint,
            (newFingerprint) {
              // Callback when authentication succeeds
              isAuthenticated = true;
              fingerprint = newFingerprint;
              _unauthenticatedSockets.remove(socket);
              _activeConnections[fingerprint!] = MapEntry(socket, reassembler);
            },
          );
        }
      },
      onError: (dynamic error) {
        _cleanupSocket(socket, fingerprint);
      },
      onDone: () {
        _cleanupSocket(socket, fingerprint);
      },
    );
  }

  /// Handles a single, complete, reassembled message.
  void _processCompleteMessage(
    SecureSocket socket,
    PacketReassembler reassembler,
    Uint8List message,
    bool isAuthenticated,
    String? fingerprint,
    Function(String) onAuthSuccess,
  ) {
    // --- AUTHENTICATION PHASE ---
    if (!isAuthenticated) {
      // We only accept an AUTH packet (0x03) here.
      if (message.isNotEmpty && message[0] == MessageType.auth.value) {
        try {
          // Payload is the PEM string bytes
          final pemBytes = message.sublist(1);
          final pemString = utf8.decode(pemBytes);
          final claimedFingerprint = _getFingerprintFromCertPem(pemString);

          // Check if this fingerprint is in our Trust Database
          if (_isTrusted(claimedFingerprint)) {
            onAuthSuccess(claimedFingerprint);
          } else {
            socket.write('REJECTED\n');
            socket.destroy();
          }
        } catch (e) {
          socket.destroy();
        }
      } else {
        // Received non-auth packet while unauthenticated
        socket.destroy();
      }
      return;
    }

    // --- ESTABLISHED PHASE ---
    if (fingerprint != null) {
      // Pass the valid, reassembled message to the router
      _messageRouter.handleData(message, fingerprint);
    }
  }

  void _cleanupSocket(SecureSocket socket, String? fingerprint) {
    socket.destroy();
    _unauthenticatedSockets.remove(socket);
    if (fingerprint != null) {
      _activeConnections.remove(fingerprint);
    }
  }

  Future<void> connectToPeer(DiscoveredPeer peer) async {
    if (_activeConnections.containsKey(peer.id)) {
      return;
    }

    try {
      // 1. Establish TLS Tunnel (Client Side)
      final socket = await SecureSocket.connect(
        peer.host,
        peer.port,
        onBadCertificate: (X509Certificate cert) {
          final fp = _getFingerprintFromCert(cert);
          final trusted = (fp == peer.id) || _isTrusted(fp);
          return trusted;
        },
      );

      // Send our Identity (Auth Packet) immediately.
      // We MUST frame this with the 4-byte length header so the receiver's
      // PacketReassembler can handle it correctly.
      final authPayloadBuilder = BytesBuilder();
      authPayloadBuilder.addByte(MessageType.auth.value);
      authPayloadBuilder.add(utf8.encode(_identity.certificate!.plain!));
      final payload = authPayloadBuilder.toBytes();

      final frameBuilder = BytesBuilder();
      final lengthData = ByteData(4)..setUint32(0, payload.length);
      frameBuilder.add(lengthData.buffer.asUint8List());
      frameBuilder.add(payload);

      socket.add(frameBuilder.toBytes());
      await socket.flush();

      // 3. Register the connection
      // We treat this as authenticated immediately because we performed the
      // verification in `onBadCertificate`.
      _handleSocketStream(socket, preKnownFingerprint: peer.id);
    } catch (e) {
      print('Failed to connect to peer ${peer.id}: $e');
    }
  }

  /// Sends a raw byte payload to all connected and trusted peers.
  /// NOTE: The `data` passed here MUST already be framed (have the length header)
  /// by the caller (e.g., VaultFileSender).
  Future<void> broadcast(Uint8List data) async {
    if (_activeConnections.isEmpty) {
      return;
    }

    final List<String> disconnectedPeers = [];

    for (final entry in _activeConnections.entries) {
      final fingerprint = entry.key;
      final socket = entry.value.key; // The SecureSocket is the key in MapEntry

      try {
        socket.add(data);
        await socket.flush();
      } catch (e) {
        disconnectedPeers.add(fingerprint);
      }
    }

    for (final fingerprint in disconnectedPeers) {
      // We can't easily access the socket to clean up by ID here without map lookup
      if (_activeConnections.containsKey(fingerprint)) {
        _cleanupSocket(_activeConnections[fingerprint]!.key, fingerprint);
      }
    }
  }

  /// Sends a stream of data to all connected and trusted peers.
  ///
  /// [header] is sent first (e.g. framing + metadata).
  /// [dataStreamFactory] is a callback that produces a [Stream] of the file content.
  /// We need a factory because we must create a fresh stream for each peer socket.
  Future<void> broadcastStream({
    required Uint8List header,
    required Stream<List<int>> Function() dataStreamFactory,
    required int totalSize,
    void Function(int sent)? onProgress,
  }) async {
    if (_activeConnections.isEmpty) return;

    final List<String> disconnectedPeers = [];
    final List<Future<void>> tasks = [];

    // Track bytes sent for progress reporting.
    // Note: If sending to multiple peers, we report "100%" when ONE peer finishes
    // or average them? Simplest is to track the *first* peer's progress for UI.
    int bytesSentSoFar = 0;

    // Header is sent immediately, count it.
    bytesSentSoFar += header.length;

    for (final entry in _activeConnections.entries) {
      final fingerprint = entry.key;
      final socket = entry.value.key;

      tasks.add(
        Future(() async {
          try {
            // 1. Write the header
            socket.add(header);

            // 2. Prepare the stream with progress tracking
            Stream<List<int>> stream = dataStreamFactory();

            // Only the first task updates the global progress UI to avoid flickering
            bool isPrimaryTracker = (tasks.isEmpty);

            stream = stream.map((chunk) {
              if (isPrimaryTracker) {
                bytesSentSoFar += chunk.length;
                onProgress?.call(bytesSentSoFar);
              }
              return chunk;
            });

            // 3. Pipe the stream
            await socket.addStream(stream);
            await socket.flush();
          } catch (e) {
            disconnectedPeers.add(fingerprint);
          }
        }),
      );
    }

    await Future.wait(tasks);
    _cleanupDisconnectedPeers(disconnectedPeers);
  }

  void _cleanupDisconnectedPeers(List<String> peers) {
    for (final fingerprint in peers) {
      if (_activeConnections.containsKey(fingerprint)) {
        _cleanupSocket(_activeConnections[fingerprint]!.key, fingerprint);
      }
    }
  }

  void dispose() {
    _server?.close();
    _server = null;
    for (final entry in _activeConnections.values) {
      entry.key.destroy(); // Destroy socket
    }
    for (final socket in _unauthenticatedSockets) {
      socket.destroy();
    }
    _activeConnections.clear();
    _unauthenticatedSockets.clear();
  }
}
