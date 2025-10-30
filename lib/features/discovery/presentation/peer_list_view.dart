import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:local_sync/features/discovery/data/discovery_providers.dart';
import 'package:local_sync/features/discovery/domain/discovered_peer.dart';

/// A widget that handles the state (loading, error, data) of the
/// discovered peers list.
class PeerListView extends ConsumerWidget {
  const PeerListView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // We watch the provider *here*, inside the new widget.
    final peersAsync = ref.watch(discoveredPeersProvider);

    // We return the Card and the .when() block that was
    // previously in main.dart.
    return Card(
      elevation: 2,
      color: Theme.of(context).colorScheme.surface,
      child: peersAsync.when(
        // We now pass the data to our new, private widget.
        data: (peers) => _PeerList(peers: peers),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, stack) => Center(
          child: Text(
            'Error discovering peers:\n$err',
            style: const TextStyle(color: Colors.red),
          ),
        ),
      ),
    );
  }

  // The _buildPeersList method has been removed from here.
}

class _PeerList extends StatelessWidget {
  final List<DiscoveredPeer> peers;
  const _PeerList({required this.peers});

  @override
  Widget build(BuildContext context) {
    if (peers.isEmpty) {
      return const Center(
        child: Text(
          'Listening for peers...\nMake sure another device is running this app.',
          textAlign: TextAlign.center,
          style: TextStyle(color: Colors.grey),
        ),
      );
    }

    return ListView.builder(
      itemCount: peers.length,
      itemBuilder: (context, index) {
        final peer = peers[index];
        return ListTile(
          leading: const Icon(Icons.computer),
          title: Text(peer.name),
          subtitle: Text(
            '${peer.host}:${peer.port}\nID: ...${peer.id.substring(peer.id.length - 8)}',
            style: const TextStyle(fontFamily: 'monospace', fontSize: 10),
          ),
        );
      },
    );
  }
}
