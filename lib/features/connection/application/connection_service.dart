import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:basic_utils/basic_utils.dart';
import 'package:local_sync/features/discovery/domain/discovered_peer.dart';
import 'package:local_sync/features/identity/domain/device_identity.dart';

typedef TrustValidator = bool Function(String fingerprint);

class ConnectionService {
  final DeviceIdentity _identity;
  final TrustValidator _isTrusted;
  SecureServerSocket? _server;
  final SecurityContext _securityContext;

  ConnectionService({
    required DeviceIdentity identity,
    required TrustValidator isTrusted,
  }) : _identity = identity,
       _isTrusted = isTrusted,
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
    return certData.sha256Thumbprint!;
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

      _server?.listen(
        (SecureSocket socket) {
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
        },
        onError: (error) {
          // Handle server listen error
        },
      );
    } catch (e) {
      // Handle server start error
    }
  }

  /// Handles an established, trusted connection using the stream API.
  void _handleConnection(SecureSocket socket, String fingerprint) {
    socket.listen(
      (List<int> data) {
        final message = String.fromCharCodes(data);
        // Handle incoming data
        socket.write('Server acknowledges: $message');
      },
      onError: (dynamic error) {
        // Handle connection error
      },
      onDone: () {
        // Handle connection closed
      },
    );
  }

  Future<void> connectToPeer(DiscoveredPeer peer) async {
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

      // We can get the fingerprint again just to be sure
      _getFingerprintFromCert(socket.peerCertificate!);

      socket.write('Hello from ${_identity.fingerprint}!');

      /// Listen to the socket stream for data, errors, and closure.
      socket.listen(
        (List<int> data) {
          // Handle incoming data from server
        },
        onError: (dynamic error) {
          // Handle client error
        },
        onDone: () {
          // Handle client disconnected
        },
      );
    } catch (e) {
      // Handle connection error
    }
  }

  void dispose() {
    _server?.close();
    _server = null;
  }
}
