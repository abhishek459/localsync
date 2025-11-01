import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:local_sync/features/connection/application/connection_service.dart';
import 'package:local_sync/features/identity/data/identity_providers.dart';
import 'package:local_sync/features/identity/domain/device_identity.dart';

/// Manages the lifecycle of the ConnectionService.
/// This provider ensures the secure server starts as soon as the
/// app has its identity.
final connectionServiceProvider = Provider<ConnectionService>((ref) {
  // We depend on our device's identity to be ready.
  final identityAsync = ref.watch(deviceIdentityProvider);

  final identity = identityAsync.value;

  // If identity is not loaded, we can't start the server.
  // We return a "dummy" service that does nothing.
  if (identity == null || identity.fingerprint.isEmpty) {
    // We use the 'empty' identity to satisfy the constructor.
    // This service instance will be thrown away and replaced
    // as soon as the real identity is loaded.
    return ConnectionService(DeviceIdentity.empty);
  }

  // Identity is ready, create the real service.
  final service = ConnectionService(identity);

  // Start the server immediately.
  service.startServer();

  // Register a cleanup function to stop the server when the provider is disposed.
  ref.onDispose(() {
    service.dispose();
  });

  return service;
});
