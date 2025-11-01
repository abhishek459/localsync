import 'dart:io';
import 'dart:typed_data';

import 'package:local_sync/features/discovery/domain/discovered_peer.dart';
import 'package:local_sync/features/identity/domain/device_identity.dart';

/// Handles the creation and management of secure TLS connections.
class ConnectionService {
  final DeviceIdentity _identity;
  SecureServerSocket? _serverSocket;

  ConnectionService(this._identity);

  /// This is our "dummy" trust manager for testing.
  /// It accepts all self-signed certificates.
  /// This is ONLY used by the CLIENT.
  bool _dummyTrustCallback(X509Certificate certificate) {
    print('--- [ConnectionService] ---');
    print('[DUMMY TRUST] Received self-signed certificate:');
    print('  Subject: ${certificate.subject}');
    print('  Issuer: ${certificate.issuer}');
    print('  [DUMMY TRUST] Forcing trust. This is for testing only.');
    print('---------------------------');
    return true; // <-- TODO: Remove THE "false" OVERRIDE once everything is ready.
  }

  SecurityContext _createSecurityContext() {
    if (_identity.certificate == null ||
        _identity.certificate!.plain == null ||
        _identity.privateKeyPem == null) {
      throw StateError(
        'Attempted to create SecurityContext with an incomplete identity.',
      );
    }

    final context = SecurityContext();

    // Load our public certificate chain.
    // The .plain property is the raw PEM string.
    context.useCertificateChainBytes(_identity.certificate!.plain!.codeUnits);

    // Load our private key.
    context.usePrivateKeyBytes(_identity.privateKeyPem!.codeUnits);

    return context;
  }

  /// Starts the secure server to listen for incoming connections.
  Future<void> startServer() async {
    if (_identity.fingerprint.isEmpty || _serverSocket != null) {
      return;
    }

    try {
      final context = _createSecurityContext();
      // Bind the server to all network interfaces on our broadcast port.
      _serverSocket = await SecureServerSocket.bind(
        InternetAddress.anyIPv4,
        45678, // The same port we broadcasted in Step 2
        context,
        requestClientCertificate: false,
        requireClientCertificate: false,
      );

      print('[ConnectionService] ✅ Secure server started on port 45678');

      // Listen for incoming client connections
      _serverSocket!.listen(
        (SecureSocket socket) {
          print(
            '[ConnectionService] 🤝 Client connected: ${socket.remoteAddress.address}',
          );
          // We can now listen for data, send data, etc.
          // For now, just listen and print any data we receive.
          socket.listen(
            (Uint8List data) {
              final message = String.fromCharCodes(data);
              print('[ConnectionService] 📩 Received data: $message');
              // As a test, let's just echo it back
              socket.write('Server acknowledges: $message');
            },
            onDone: () {
              print(
                '[ConnectionService] 🚫 Client disconnected: ${socket.remoteAddress.address}',
              );
            },
            onError: (error) {
              print('[ConnectionService] ❌ Socket Error: $error');
            },
          );
        },
        onError: (error) {
          print('[ConnectionService] ❌ Server Error: $error');
        },
      );
    } catch (e) {
      print('[ConnectionService] ❌ FAILED to start server: $e');
    }
  }

  /// Connects to a discovered peer.
  Future<void> connectToPeer(DiscoveredPeer peer) async {
    // CORRECTION: Add guard clause.
    if (_identity.fingerprint.isEmpty) {
      print('[ConnectionService] ❌ Cannot connect: Identity is not loaded.');
      return;
    }

    print(
      '[ConnectionService] Client attempting to connect to ${peer.name} at ${peer.host}:${peer.port}...',
    );
    try {
      final context = _createSecurityContext();
      final socket = await SecureSocket.connect(
        peer.host,
        peer.port,
        // The onBadCertificate callback is correct here (on the client).
        onBadCertificate: _dummyTrustCallback,
        // We pass our identity context to prove who *we* are to the server.
        context: context,
        // Set a reasonable timeout
        timeout: const Duration(seconds: 5),
      );

      print('[ConnectionService] ✅ Client connected! Handshake complete.');

      // We are connected! Let's send a test message.
      socket.write('Hello from ${_identity.fingerprint.substring(0, 8)}!');

      // Listen for the server's response
      socket.listen(
        (Uint8List data) {
          final message = String.fromCharCodes(data);
          print('[ConnectionService] 📩 Received from server: $message');
        },
        onDone: () {
          print('[ConnectionService] 🚫 Server disconnected.');
          socket.destroy();
        },
      );
    } catch (e) {
      print('[ConnectionService] ❌ FAILED to connect: $e');
    }
  }

  /// Shuts down the server socket.
  void dispose() {
    _serverSocket?.close();
    _serverSocket = null;
    print('[ConnectionService] 🛑 Secure server stopped.');
  }
}
