import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:basic_utils/basic_utils.dart';
import 'package:local_sync/features/discovery/domain/discovered_peer.dart';
import 'package:local_sync/features/identity/domain/device_identity.dart';
import 'package:local_sync/features/transport/message_router.dart';

typedef TrustValidator = bool Function(String fingerprint);

class ConnectionService {
  final DeviceIdentity _identity;
  final TrustValidator _isTrusted;
  final MessageRouter _messageRouter;
  SecureServerSocket? _server;
  final SecurityContext _securityContext;

  /// A map of all active, trusted sockets, keyed by their device fingerprint.
  final Map<String, SecureSocket> _activeSockets = {};

  ConnectionService({
    required DeviceIdentity identity,
    required TrustValidator isTrusted,
    required MessageRouter messageRouter,
  }) : _identity = identity,
       _isTrusted = isTrusted,
       _messageRouter = messageRouter,
       _securityContext = SecurityContext() {
    _securityContext.useCertificateChainBytes(
      Uint8List.fromList(utf8.encode(_identity.certificate!.plain!)),
    );
    _securityContext.usePrivateKeyBytes(
      Uint8List.fromList(utf8.encode(_identity.privateKeyPem!)),
    );
  }

  String _getFingerprintFromCert(X509Certificate cert) {
    final pem = cert.pem;
    final certData = X509Utils.x509CertificateFromPem(pem);
    return certData.sha256Thumbprint!.replaceAll(':', '').toLowerCase();
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
        requireClientCertificate: true,
        requestClientCertificate: true,
      );

      _server?.listen((SecureSocket socket) {
        final peerCert = socket.peerCertificate;
        if (peerCert == null) {
          socket.destroy();
          return;
        }

        final fingerprint = _getFingerprintFromCert(peerCert);
        if (_isTrusted(fingerprint)) {
          _handleConnection(socket, fingerprint);
        } else {
          socket.destroy();
        }
      }, onError: (error) {});
    } catch (e) {
      // Failed to start server
    }
  }

  /// Handles an established, trusted connection using the stream API.
  void _handleConnection(SecureSocket socket, String fingerprint) {
    _activeSockets[fingerprint] = socket;

    socket.listen(
      (List<int> data) {
        _messageRouter.handleData(Uint8List.fromList(data), fingerprint);
      },
      onError: (dynamic error) {
        socket.destroy();
        _activeSockets.remove(fingerprint);
      },
      onDone: () {
        socket.destroy();
        _activeSockets.remove(fingerprint);
      },
    );
  }

  Future<void> connectToPeer(DiscoveredPeer peer) async {
    if (_activeSockets.containsKey(peer.id)) {
      return;
    }

    try {
      final socket = await SecureSocket.connect(
        peer.host,
        peer.port,
        context: _securityContext,
        onBadCertificate: (X509Certificate cert) {
          final fingerprint = _getFingerprintFromCert(cert);
          return _isTrusted(fingerprint);
        },
      );

      final fingerprint = _getFingerprintFromCert(socket.peerCertificate!);
      _activeSockets[fingerprint] = socket;

      socket.listen(
        (List<int> data) {
          _messageRouter.handleData(Uint8List.fromList(data), fingerprint);
        },
        onError: (dynamic error) {
          socket.destroy();
          _activeSockets.remove(fingerprint);
        },
        onDone: () {
          socket.destroy();
          _activeSockets.remove(fingerprint);
        },
      );
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
      _activeSockets[fingerprint]?.destroy();
      _activeSockets.remove(fingerprint);
    }
  }

  void dispose() {
    _server?.close();
    _server = null;
    for (final socket in _activeSockets.values) {
      socket.destroy();
    }
    _activeSockets.clear();
  }
}
