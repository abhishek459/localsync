import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:local_sync/features/pairing/domain/show_my_info_state.dart';
import 'package:local_sync/features/pairing/data/pairing_providers.dart';
import 'package:local_sync/features/pairing/presentation/widgets/show_qr_dialog.dart';

class ShowMyInfoWidget extends ConsumerWidget {
  const ShowMyInfoWidget({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(showMyInfoProvider);
    final authNotifier = ref.read(showMyInfoProvider.notifier);

    switch (authState.status) {
      case ShowMyInfoStatus.unauthenticated:
        return Center(
          child: FilledButton.icon(
            icon: const Icon(Icons.visibility),
            label: const Text('Show My Connection Info'),
            onPressed: authNotifier.authenticate,
          ),
        );

      case ShowMyInfoStatus.authenticating:
        return const Center(child: CircularProgressIndicator());

      case ShowMyInfoStatus.error:
        return Column(
          children: [
            Text(
              'Error: ${authState.errorMessage}',
              style: const TextStyle(color: Colors.red),
            ),
            const SizedBox(height: 8),
            ElevatedButton(
              onPressed: authNotifier.authenticate,
              child: const Text('Try Again'),
            ),
          ],
        );

      case ShowMyInfoStatus.success:
        // Auth is successful. NOW we watch the data provider.
        final pairingDataAsync = ref.watch(myPairingDataProvider);

        return pairingDataAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, st) => Column(
            children: [
              Text('Error: $e', style: const TextStyle(color: Colors.red)),
              const SizedBox(height: 8),
              ElevatedButton(
                onPressed: () => ref.invalidate(myPairingDataProvider),
                child: const Text('Retry Data Fetch'),
              ),
            ],
          ),
          data: (pairingData) {
            // Both auth and data are successful.
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'Your Connection Info',
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                const SizedBox(height: 16),
                _buildInfoRow(context, 'Wi-Fi IP Address:', pairingData.ip),
                const SizedBox(height: 12),
                _buildInfoRow(context, 'Port:', pairingData.port.toString()),
                const SizedBox(height: 12),
                _buildInfoRow(
                  context,
                  'Device Fingerprint:',
                  pairingData.fingerprint,
                ),
                const SizedBox(height: 24),
                ElevatedButton.icon(
                  icon: const Icon(Icons.qr_code_2),
                  label: const Text('Show QR Code to Scan'),
                  onPressed: () {
                    showDialog(
                      context: context,
                      builder: (context) =>
                          ShowMyQrDialog(pairingData: pairingData),
                    );
                  },
                ),
              ],
            );
          },
        );
    }
  }

  Widget _buildInfoRow(BuildContext context, String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: Theme.of(context).textTheme.labelLarge),
        Row(
          children: [
            Expanded(
              child: SelectableText(
                value,
                style: const TextStyle(fontFamily: 'monospace', fontSize: 16),
              ),
            ),
            IconButton(
              icon: const Icon(Icons.copy, size: 16),
              onPressed: () {
                Clipboard.setData(ClipboardData(text: value));
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Copied to clipboard'),
                    duration: Duration(seconds: 1),
                  ),
                );
              },
            ),
          ],
        ),
      ],
    );
  }
}
