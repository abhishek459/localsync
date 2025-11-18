import 'package:local_sync/features/connection/data/connection_providers.dart';
import 'package:local_sync/features/discovery/data/discovery_providers.dart';
import 'package:local_sync/features/trust/data/trust_providers.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'auto_connection_manager.g.dart';

/// Watches discovered peers and the trust list.
/// Automatically initiates connections to peers that are trusted.
@Riverpod(keepAlive: true)
void autoConnectionManager(Ref ref) {
  // 1. Listen to the list of discovered peers
  final peersAsync = ref.watch(discoveredPeersProvider);

  // 2. Listen to the trust list (so if we trust someone new, we connect instantly)
  final trustListAsync = ref.watch(trustListProvider);

  // 3. Get the connection service (to perform the connection)
  final connectionServiceAsync = ref.watch(connectionServiceProvider);

  // Proceed only if all dependencies are ready
  if (peersAsync.hasValue &&
      trustListAsync.hasValue &&
      connectionServiceAsync.hasValue) {
    final peers = peersAsync.value!;
    final trustedPeers = trustListAsync.value!;
    final connectionService = connectionServiceAsync.value!;

    for (final peer in peers) {
      // Check if this discovered peer is in our trust list
      final isTrusted = trustedPeers.any((tp) => tp.fingerprint == peer.id);

      if (isTrusted) {
        // The ConnectionService.connectToPeer method handles de-duplication
        // (it won't connect if a socket already exists), so we can safely call this.
        connectionService.connectToPeer(peer);
      }
    }
  }
}
