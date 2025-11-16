import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:local_sync/features/pairing/domain/show_my_info_state.dart';
import 'package:local_sync/features/pairing/data/pairing_providers.dart';
import 'package:local_sync/features/pairing/presentation/widgets/display_pairing_info.dart';
import 'package:local_sync/features/shared/presentation/app_sizes.dart';

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
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
            const SizedBox(height: AppSizes.p2),
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
              Text(
                'Error: $e',
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
              const SizedBox(height: AppSizes.p2),
              ElevatedButton(
                onPressed: () => ref.invalidate(myPairingDataProvider),
                child: const Text('Retry Data Fetch'),
              ),
            ],
          ),
          data: (pairingData) {
            // Both auth and data are successful.
            return DisplayPairingInfo(pairingData: pairingData);
          },
        );
    }
  }
}
