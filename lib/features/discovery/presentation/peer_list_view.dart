import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:local_sync/features/connection/data/connection_providers.dart';
import 'package:local_sync/features/discovery/data/discovery_providers.dart';
import 'package:local_sync/features/discovery/domain/discovered_peer.dart';
import 'package:local_sync/features/shared/application/app_notification_provider.dart';

/// A widget that handles the state (loading, error, data) of the
/// discovered peers list.
class PeerListView extends ConsumerWidget {
  const PeerListView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final peersAsync = ref.watch(discoveredPeersProvider);
    // Watch the connection service to know when it's ready
    final connectionServiceAsync = ref.watch(connectionServiceProvider);

    return peersAsync.when(
      data: (peers) {
        // We can only tap peers if the connection service is
        // successfully loaded (i.e., has a value).
        final bool isConnectionServiceReady = connectionServiceAsync.hasValue;

        void handlePeerTap(DiscoveredPeer peer) {
          NotificationReporter.reportInfo(
            'Attempting to connect to ${peer.name}...',
          );

          ref.read(connectionServiceProvider).value!.connectToPeer(peer);
        }

        return _PeerList(
          peers: peers,
          isConnectionServiceReady: isConnectionServiceReady,
          onPeerTapped: handlePeerTap,
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (err, stack) => Center(
        child: Text(
          'Error discovering peers:\n$err',
          style: TextStyle(color: Theme.of(context).colorScheme.error),
        ),
      ),
    );
  }
}

class _PeerList extends StatelessWidget {
  final List<DiscoveredPeer> peers;
  final bool isConnectionServiceReady;
  final void Function(DiscoveredPeer) onPeerTapped;

  const _PeerList({
    required this.peers,
    required this.isConnectionServiceReady,
    required this.onPeerTapped,
  });

  @override
  Widget build(BuildContext context) {
    if (peers.isEmpty) {
      return Center(
        child: Text(
          'Listening for peers...\nMake sure another device is running this app.',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
      );
    }

    return ListView.builder(
      itemCount: peers.length,
      itemBuilder: (context, index) {
        final peer = peers[index];
        return ListTile(
          isThreeLine: true,
          leading: const Icon(Icons.computer),
          title: Text(peer.name),
          subtitle: Text(
            '${peer.host}:${peer.port}\nID: ...${peer.id.substring(peer.id.length - 8)}',
            style: Theme.of(context).textTheme.labelSmall,
          ),
          // Disable the tap if the service isn't ready
          enabled: isConnectionServiceReady,
          onTap: () => onPeerTapped(peer),
        );
      },
    );
  }
}
