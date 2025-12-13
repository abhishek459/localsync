import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:local_sync/features/master_key/data/master_key_providers.dart';
import 'package:local_sync/features/master_key/data/master_key_storer_provider.dart';
import 'package:local_sync/features/shared/application/app_notification_provider.dart';
import 'package:local_sync/features/shared/presentation/app_sizes.dart';

class GenerateMasterKeyScreen extends ConsumerStatefulWidget {
  const GenerateMasterKeyScreen({super.key});

  @override
  ConsumerState<GenerateMasterKeyScreen> createState() =>
      _GenerateMasterKeyScreenState();
}

class _GenerateMasterKeyScreenState
    extends ConsumerState<GenerateMasterKeyScreen> {
  AsyncValue<String> _mnemonicState = const AsyncValue.loading();
  bool _hasConfirmed = false;

  @override
  void initState() {
    super.initState();
    // Generate the mnemonic once when the screen is first built.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _generate();
    });
  }

  Future<void> _generate() async {
    try {
      final mnemonic = await ref
          .read(masterKeyServiceProvider)
          .generateMnemonic();
      if (mounted) {
        setState(() {
          _mnemonicState = AsyncValue.data(mnemonic);
        });
      }
    } catch (e, st) {
      if (mounted) {
        setState(() {
          _mnemonicState = AsyncValue.error(e, st);
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final storer = ref.watch(masterKeyStorerProvider);
    final storerNotifier = ref.read(masterKeyStorerProvider.notifier);

    // Listen to the storer provider for error/success states
    ref.listen(masterKeyStorerProvider, (prev, next) {
      if (next is AsyncError) {
        NotificationReporter.reportError(next.error, stack: next.stackTrace);
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
      appBar: AppBar(title: const Text('Create Master Key')),
      body: Center(
        child: _mnemonicState.when(
          loading: () => const CircularProgressIndicator(),
          error: (err, stack) => Text('Error: $err'),
          data: (mnemonic) => ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth: AppSizes.layoutConstraintMedium,
            ),
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(AppSizes.p6),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'Your New Master Key',
                    style: textTheme.headlineSmall,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: AppSizes.p4),
                  Text(
                    'Write these 24 words down in a safe place. This is the only way to recover your Secure Vault.',
                    style: textTheme.bodyLarge,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 24),
                  Card(
                    elevation: 0,
                    color: Theme.of(
                      context,
                    ).colorScheme.surfaceContainerHighest,
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: SelectableText(
                        mnemonic,
                        style: textTheme.titleMedium?.copyWith(
                          fontFamily: 'monospace',
                          letterSpacing: 1.1,
                          height: 1.5,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ),
                  const SizedBox(height: AppSizes.p4),
                  TextButton.icon(
                    icon: const Icon(Icons.copy, size: 16),
                    label: const Text('Copy to Clipboard'),
                    onPressed: () {
                      Clipboard.setData(ClipboardData(text: mnemonic));
                      NotificationReporter.reportInfo('Copied to clipboard');
                    },
                  ),
                  const SizedBox(height: 32),
                  CheckboxListTile(
                    title: const Text('I have saved this phrase'),
                    value: _hasConfirmed,
                    onChanged: (value) {
                      setState(() {
                        _hasConfirmed = value ?? false;
                      });
                    },
                  ),
                  const SizedBox(height: 24),
                  FilledButton(
                    onPressed: _hasConfirmed && !storer.isLoading
                        ? () => storerNotifier.storeMnemonic(mnemonic)
                        : null,
                    style: FilledButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                        vertical: AppSizes.p4,
                      ),
                    ),
                    child: storer.isLoading
                        ? const SizedBox.square(
                            dimension: AppSizes.p6,
                            child: CircularProgressIndicator(strokeWidth: 3),
                          )
                        : const Text('Confirm & Store Key'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
