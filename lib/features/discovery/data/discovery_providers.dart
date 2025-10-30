import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:local_sync/features/discovery/application/discovery_service.dart';
import 'package:local_sync/features/discovery/domain/discovered_peer.dart';
import 'package:local_sync/features/identity/data/identity_providers.dart';

/// Provides a singleton instance of DeviceInfoPlugin.
final deviceInfoProvider = Provider((_) => DeviceInfoPlugin());

/// Manages the lifecycle of the DiscoveryService.
/// This provider will return `null` until the device identity is ready.
final discoveryServiceProvider = Provider<DiscoveryService?>((ref) {
  // We depend on our device's identity to be ready.
  final identityAsync = ref.watch(deviceIdentityProvider);
  final deviceInfo = ref.watch(deviceInfoProvider);

  // Get the identity value. It will be null if loading or in error state.
  final identity = identityAsync.value;

  // If identity is not ready, we cannot create the service.
  if (identity == null) {
    return null;
  }

  // Identity is ready, create the real service.
  final service = DiscoveryService(identity: identity, deviceInfo: deviceInfo);

  // Start broadcasting immediately.
  service.startBroadcast();

  // Register a cleanup function to stop broadcasting when the provider is disposed.
  ref.onDispose(() {
    service.dispose();
  });

  return service;
});

/// Provides a stream of the list of discovered peers on the network.
/// The UI will watch this provider to get a live-updated list.
final discoveredPeersProvider = StreamProvider<List<DiscoveredPeer>>((ref) {
  // Watch the discovery service. It will be null until the identity is loaded.
  final discoveryService = ref.watch(discoveryServiceProvider);

  // If the service isn't ready (because identity isn't ready),
  // just return an empty stream.
  if (discoveryService == null) {
    return Stream.value([]);
  }

  // The service is ready, start discovering and return the peer stream.
  return discoveryService.discoverPeers();
});
