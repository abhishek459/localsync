import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:local_sync/features/master_key/data/master_key_storer_provider.dart';
import 'package:local_sync/features/shared/application/app_notification_provider.dart';
import 'package:local_sync/features/shared/domain/app_notification.dart';
import 'package:local_sync/features/shared/presentation/app_sizes.dart';

class ImportMasterKeyScreen extends ConsumerStatefulWidget {
  const ImportMasterKeyScreen({super.key});

  @override
  ConsumerState<ImportMasterKeyScreen> createState() =>
      _ImportMasterKeyScreenState();
}

class _ImportMasterKeyScreenState extends ConsumerState<ImportMasterKeyScreen> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final storer = ref.watch(masterKeyStorerProvider);
    final storerNotifier = ref.read(masterKeyStorerProvider.notifier);

    // Listen to the provider for success/error states
    ref.listen(masterKeyStorerProvider, (prev, next) {
      if (next is AsyncError) {
        // _showError(next.error.toString());
        NotificationReporter.reportError(
          next.error,
          stack: next.stackTrace,
          userFriendlyMessage: next.error.toString(),
          type: NotificationType.dialog,
        );
      }
      if (next is AsyncData) {
        // On success, pop all the way back to the home screen
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            Navigator.of(context).popUntil((route) => route.isFirst);
          }
        });
      }
    });

    return Scaffold(
      appBar: AppBar(title: const Text('Import Master Key')),
      body: Center(
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxWidth: AppSizes.layoutConstraintMedium,
          ),
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(AppSizes.p6),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'Import Your Master Key',
                  style: Theme.of(context).textTheme.headlineSmall,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: AppSizes.p4),
                Text(
                  'Enter your 24-word recovery phrase below to restore access to your Secure Vault.',
                  style: Theme.of(context).textTheme.bodyLarge,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),
                TextField(
                  controller: _controller,
                  minLines: 3,
                  maxLines: 5,
                  autocorrect: false,
                  enableSuggestions: false,
                  style: const TextStyle(
                    fontFamily: 'monospace',
                    letterSpacing: 1.1,
                  ),
                  decoration: const InputDecoration(
                    labelText: '24-Word Mnemonic Phrase',
                    border: OutlineInputBorder(),
                    contentPadding: EdgeInsets.all(AppSizes.p4),
                  ),
                ),
                const SizedBox(height: 32),
                FilledButton(
                  // Disable button when storing
                  onPressed: storer.isLoading
                      ? null
                      : () {
                          FocusManager.instance.primaryFocus?.unfocus();
                          storerNotifier.storeMnemonic(_controller.text.trim());
                        },
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: AppSizes.p4),
                  ),
                  child: storer.isLoading
                      ? const SizedBox.square(
                          dimension: 24,
                          child: CircularProgressIndicator(strokeWidth: 3),
                        )
                      : const Text('Confirm & Import Key'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
