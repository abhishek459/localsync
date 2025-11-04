import 'package:device_info_plus/device_info_plus.dart';
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

/// Manages the lifecycle of the DiscoveryService.
/// This provider now asynchronously waits for the device identity to be ready.
@Riverpod(keepAlive: true)
Future<DiscoveryService> discoveryService(Ref ref) async {
  // We depend on our device's identity to be ready.
  final identity = await ref.watch(deviceIdentityProvider.future);
  final deviceInfo = ref.watch(deviceInfoProvider);

  // Identity is ready, create the real service.
  final service = DiscoveryService(identity: identity, deviceInfo: deviceInfo);

  // Start broadcasting immediately.
  service.startBroadcast();

  // Register a cleanup function to stop broadcasting when the provider is disposed.
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
