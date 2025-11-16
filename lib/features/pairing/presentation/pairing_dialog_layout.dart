import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:local_sync/features/pairing/data/pairing_providers.dart';
import 'package:local_sync/features/pairing/domain/show_my_info_state.dart';
import 'package:local_sync/features/pairing/presentation/tabs/manual_pairing_tab.dart';
import 'package:local_sync/features/pairing/presentation/widgets/display_pairing_info.dart';
import 'package:local_sync/features/shared/presentation/app_sizes.dart';

/// A layout specifically for the desktop "Add Device" dialog.
/// It shows "Your Info" (QR) and "Connect to Peer" (Manual) side-by-side.
class PairingDialogLayout extends StatelessWidget {
  const PairingDialogLayout({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Add a New Device'),
        // Adds a close button to the dialog
        actions: [
          IconButton(
            icon: const Icon(Icons.close),
            onPressed: () => Navigator.of(context).pop(),
          ),
        ],
      ),
      body: const Row(
        children: [
          // Left Panel: Show My Info
          Expanded(flex: 1, child: _YourInfoPanel()),
          VerticalDivider(width: 1),
          // Right Panel: Manual Connection
          Expanded(
            flex: 1,
            // We can reuse the ManualPairingTab widget here
            child: ManualPairingTab(),
          ),
        ],
      ),
    );
  }
}

/// This widget replaces `ShowMyInfoWidget` for the desktop dialog.
/// It handles the auth state but *directly* renders the QR code
/// and info on success, avoiding the "Show QR" button and extra dialog.
class _YourInfoPanel extends ConsumerStatefulWidget {
  const _YourInfoPanel();

  @override
  ConsumerState<_YourInfoPanel> createState() => _YourInfoPanelState();
}

class _YourInfoPanelState extends ConsumerState<_YourInfoPanel> {
  @override
  void initState() {
    super.initState();
    // Authenticate immediately on build
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(showMyInfoProvider.notifier).authenticate();
    });
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(showMyInfoProvider);

    return Padding(
      padding: const EdgeInsets.all(AppSizes.p6),
      child: _buildContent(context, authState),
    );
  }

  Widget _buildContent(BuildContext context, ShowMyInfoState authState) {
    switch (authState.status) {
      case ShowMyInfoStatus.unauthenticated:
      case ShowMyInfoStatus.authenticating:
        return const Center(child: CircularProgressIndicator());
      case ShowMyInfoStatus.error:
        return Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                'Error: ${authState.errorMessage}',
                style: TextStyle(color: Theme.of(context).colorScheme.error),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: AppSizes.p2),
              ElevatedButton(
                onPressed: ref.read(showMyInfoProvider.notifier).authenticate,
                child: const Text('Try Again'),
              ),
            ],
          ),
        );
      case ShowMyInfoStatus.success:
        // Auth is good, now get the pairing data
        final pairingDataAsync = ref.watch(myPairingDataProvider);
        return pairingDataAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, st) => Center(
            child: Text(
              'Error: $e',
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          ),
          data: (pairingData) {
            // On success, render the QR code and info *directly*
            return SingleChildScrollView(
              child: DisplayPairingInfo(pairingData: pairingData),
            );
          },
        );
    }
  }
}
