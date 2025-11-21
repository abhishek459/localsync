import 'package:local_sync/features/connection/data/connection_providers.dart';
import 'package:local_sync/features/discovery/data/discovery_providers.dart';
import 'package:local_sync/features/discovery/domain/discovered_peer.dart';
import 'package:local_sync/features/trust/data/trust_providers.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'auto_connection_manager.g.dart';

/// Watches discovered peers and the trust list.
/// Automatically initiates connections to peers that are trusted.
@Riverpod(keepAlive: true)
void autoConnectionManager(Ref ref) {
  // Define the connection logic as a reusable function
  void attemptConnections(List<DiscoveredPeer> peers) {
    // We read the trust list only when we need it (lazy read)
    final trustListState = ref.read(trustListProvider);

    // If trust list isn't loaded yet, we can't trust anyone.
    if (!trustListState.hasValue) return;

    final trustedPeers = trustListState.value!;
    final connectionServiceAsync = ref.read(connectionServiceProvider);

    // If service isn't ready, we can't connect.
    if (!connectionServiceAsync.hasValue) return;

    final connectionService = connectionServiceAsync.value!;

    for (final peer in peers) {
      final isTrusted = trustedPeers.any((tp) => tp.fingerprint == peer.id);
      if (isTrusted) {
        // Connect immediately. The service handles de-duplication internally
        // so we don't need to check active connections here.
        connectionService.connectToPeer(peer);
      }
    }
  }

  // 1. LISTEN to Discovered Peers
  // This callback only fires when the peer list actually changes.
  ref.listen(discoveredPeersProvider, (prev, next) {
    if (next.hasValue) {
      attemptConnections(next.value!);
    }
  });

  // 2. LISTEN to Trust List
  // If we trust a new device, we should check if it's already discovered and connect.
  ref.listen(trustListProvider, (prev, next) {
    if (next.hasValue) {
      // If trust list changes, re-check currently discovered peers
      final currentPeers = ref.read(discoveredPeersProvider).value;
      if (currentPeers != null) {
        attemptConnections(currentPeers);
      }
    }
  });
}
