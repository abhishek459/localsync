import 'package:device_info_plus/device_info_plus.dart';
import 'package:local_sync/features/connection/data/connection_providers.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:local_sync/features/discovery/application/discovery_service.dart';
import 'package:local_sync/features/discovery/domain/discovered_peer.dart';
import 'package:local_sync/features/identity/data/identity_providers.dart';

part 'discovery_providers.g.dart';

/// Provides a singleton instance of DeviceInfoPlugin.
@Riverpod(keepAlive: true)
DeviceInfoPlugin deviceInfo(Ref ref) {
  return DeviceInfoPlugin();
}

@Riverpod(keepAlive: true)
Future<DiscoveryService> discoveryService(Ref ref) async {
  // Use Rust Identity
  final identity = await ref.watch(networkIdentityProvider.future);

  if (identity == null) {
    throw Exception("Cannot start discovery: Identity not initialized.");
  }

  int port = await ref.watch(activePortProvider.future);

  int retryCount = 0;
  while (port == 0 && retryCount < 3) {
    // Wait a moment before retrying
    await Future.delayed(const Duration(seconds: 1));

    // Force restart of the underlying connection service
    ref.invalidate(connectionServiceProvider);
    // Invalidate local cache of the port to ensure we get the fresh value
    ref.invalidate(activePortProvider);

    port = await ref.read(activePortProvider.future);
    retryCount++;
  }

  if (port == 0) {
    throw Exception(
      "Cannot start discovery: Server port not ready after multiple restart attempts.",
    );
  }

  final deviceInfo = ref.watch(deviceInfoProvider);

  final service = DiscoveryService(
    identity: identity,
    deviceInfo: deviceInfo,
    port: port,
  );
  await service.startBroadcast();

  ref.onDispose(() {
    service.dispose();
  });

  return service;
}

/// Provides a stream of the list of discovered peers on the network.
/// The UI will watch this provider to get a live-updated list.
@Riverpod(keepAlive: true)
Stream<List<DiscoveredPeer>> discoveredPeers(Ref ref) async* {
  // Await the discovery service. This handles the loading state.
  final discoveryService = await ref.watch(discoveryServiceProvider.future);

  // The service is ready, start discovering and return the peer stream.
  yield* discoveryService.discoverPeers();
}
