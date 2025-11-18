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

class ConnectionService {
  final DeviceIdentity _identity;
  final TrustValidator _isTrusted;
  final MessageRouter _messageRouter;
  SecureServerSocket? _server;
  final SecurityContext _securityContext;

  /// A map of all active, trusted sockets, keyed by their device fingerprint.
  final Map<String, SecureSocket> _activeSockets = {};

  /// Keeps track of sockets that have connected but haven't sent their identity yet.
  /// We strictly isolate these to prevent data leakage.
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
      _securityContext.useCertificateChainBytes(certBytes);
      _securityContext.usePrivateKeyBytes(keyBytes);

      // We do NOT set trusted certificates here for the Server,
      // because we handle client auth manually in the app layer.
    } catch (e) {
      // Error loading security context
    }
  }

  /// Helper to calculate fingerprint from a raw PEM string
  String _getFingerprintFromCertPem(String pem) {
    try {
      final certData = X509Utils.x509CertificateFromPem(pem);
      return certData.sha256Thumbprint!.replaceAll(':', '').toLowerCase();
    } catch (e) {
      // Error parsing cert PEM
      return '';
    }
  }

  /// Helper to calculate fingerprint from a TLS Certificate object
  String _getFingerprintFromCert(X509Certificate cert) {
    return _getFingerprintFromCertPem(cert.pem);
  }

  Future<void> startServer() async {
    if (_server != null) {
      return;
    }

    try {
      _server = await SecureServerSocket.bind(
        InternetAddress.anyIPv4,
        45678,
        _securityContext,
        requireClientCertificate: false,
        requestClientCertificate: false,
      );

      _server?.listen((SecureSocket socket) {
        _handleSocketStream(socket);
      }, onError: (error) {});
    } catch (e) {
      // Failed to start server
    }
  }

  /// Unified handler for managing the socket lifecycle and auth state.
  void _handleSocketStream(SecureSocket socket, {String? preKnownFingerprint}) {
    // If we initiated the connection (client side), we already know the peer
    // and verified them via onBadCertificate.
    bool isAuthenticated = preKnownFingerprint != null;
    String? fingerprint = preKnownFingerprint;

    if (!isAuthenticated) {
      _unauthenticatedSockets.add(socket);

      // Security: Enforce a 10-second timeout for authentication.
      Future.delayed(const Duration(seconds: 10), () {
        if (!isAuthenticated && _unauthenticatedSockets.contains(socket)) {
          socket.destroy();
          _unauthenticatedSockets.remove(socket);
        }
      });
    } else {
      _activeSockets[fingerprint!] = socket;
    }

    socket.listen(
      (List<int> data) {
        if (data.isEmpty) return;
        final uData = Uint8List.fromList(data);

        // --- AUTHENTICATION PHASE ---
        if (!isAuthenticated) {
          // We only accept an AUTH packet (0x03) here.
          if (uData[0] == MessageType.auth.value) {
            try {
              // Payload is the PEM string bytes
              final pemBytes = uData.sublist(1);
              final pemString = utf8.decode(pemBytes);
              final claimedFingerprint = _getFingerprintFromCertPem(pemString);

              // 1. Check if this fingerprint is in our Trust Database
              if (_isTrusted(claimedFingerprint)) {
                isAuthenticated = true;
                fingerprint = claimedFingerprint;
                _unauthenticatedSockets.remove(socket);
                _activeSockets[fingerprint!] = socket;
              } else {
                socket.write('REJECTED\n'); // Optional polite notice
                socket.destroy();
              }
            } catch (e) {
              socket.destroy();
            }
          } else {
            socket.destroy();
          }
          return;
        }

        // --- ESTABLISHED PHASE ---
        // If we reach here, the socket is authenticated.
        if (fingerprint != null) {
          // Pass valid data to the router
          _messageRouter.handleData(uData, fingerprint!);
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

  void _cleanupSocket(SecureSocket socket, String? fingerprint) {
    socket.destroy();
    _unauthenticatedSockets.remove(socket);
    if (fingerprint != null) {
      _activeSockets.remove(fingerprint);
    }
  }

  Future<void> connectToPeer(DiscoveredPeer peer) async {
    if (_activeSockets.containsKey(peer.id)) {
      return;
    }

    try {
      // 1. Establish TLS Tunnel (Client Side)
      final socket = await SecureSocket.connect(
        peer.host,
        peer.port,
        context: _securityContext,
        onBadCertificate: (X509Certificate cert) {
          final fp = _getFingerprintFromCert(cert);
          final trusted = (fp == peer.id) || _isTrusted(fp);
          return trusted;
        },
      );

      // 2. Send our Identity (Auth Packet) immediately
      final authPacket = BytesBuilder();
      authPacket.addByte(MessageType.auth.value);
      authPacket.add(utf8.encode(_identity.certificate!.plain!));
      socket.add(authPacket.toBytes());
      await socket.flush();

      // 3. Register the connection
      // We treat this as authenticated immediately because we performed the
      // verification in `onBadCertificate`.
      _handleSocketStream(socket, preKnownFingerprint: peer.id);
    } catch (e) {
      // Failed to connect
    }
  }

  /// Sends a raw byte payload to all connected and trusted peers.
  Future<void> broadcast(Uint8List data) async {
    if (_activeSockets.isEmpty) {
      return;
    }

    final List<String> disconnectedPeers = [];

    for (final entry in _activeSockets.entries) {
      final fingerprint = entry.key;
      final socket = entry.value;

      try {
        socket.add(data);
        await socket.flush();
      } catch (e) {
        disconnectedPeers.add(fingerprint);
      }
    }

    for (final fingerprint in disconnectedPeers) {
      _cleanupSocket(_activeSockets[fingerprint]!, fingerprint);
    }
  }

  void dispose() {
    _server?.close();
    _server = null;
    for (final socket in _activeSockets.values) {
      socket.destroy();
    }
    for (final socket in _unauthenticatedSockets) {
      socket.destroy();
    }
    _activeSockets.clear();
    _unauthenticatedSockets.clear();
  }
}
