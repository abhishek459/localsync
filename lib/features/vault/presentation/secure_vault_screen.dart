import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:local_sync/features/shared/application/app_notification_provider.dart';
import 'package:local_sync/features/shared/presentation/app_sizes.dart';
import 'package:local_sync/features/vault/application/file_picker_service.dart';
import 'package:local_sync/features/vault/data/vault_repository.dart';
import 'package:local_sync/features/vault/data/vault_file_sender_provider.dart';
import 'package:local_sync/features/vault/data/vault_file_decrypter_provider.dart';

class SecureVaultScreen extends ConsumerWidget {
  const SecureVaultScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final vaultFilesAsync = ref.watch(vaultFilesProvider);
    final vaultFileSender = ref.watch(vaultFileSenderProvider);
    final vaultFileDecrypter = ref.watch(vaultFileDecrypterProvider);

    ref.listen(vaultFileSenderProvider, (prev, next) {
      if (next is AsyncError) {
        NotificationReporter.reportError(
          next.error,
          stack: next.stackTrace,
          userFriendlyMessage: 'Failed to send file. Please try again.',
        );
      }
      if (prev is AsyncLoading && next is AsyncData) {
        NotificationReporter.reportSuccess(
          'File added to vault and broadcasted!',
        );
      }
    });

    ref.listen(vaultFileDecrypterProvider, (prev, next) {
      if (next is AsyncLoading) {
        NotificationReporter.reportInfo('Decrypting and saving...');
      }
      if (next is AsyncError) {
        NotificationReporter.reportError(
          next.error!,
          stack: next.stackTrace,
          userFriendlyMessage: 'Failed to decrypt file. Please try again.',
        );
      }
      if (prev is AsyncLoading &&
          next is AsyncData<String?> &&
          next.value != null) {
        NotificationReporter.reportSuccess(
          'File saved to Downloads! (${next.value})',
        );
      }
    });

    return Scaffold(
      body: vaultFilesAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, stack) => Center(
          child: Text(
            'Error loading vault: $err',
            style: TextStyle(color: Theme.of(context).colorScheme.error),
          ),
        ),
        data: (files) {
          if (files.isEmpty) {
            return ListTile(
              leading: Icon(
                Icons.info_outline,
                size: 48,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
              title: const Text('Your Secure Vault is empty'),
              subtitle: Text(
                'Tap the "+" button to add a file.',
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            );
          }

          final bool isDecrypting = vaultFileDecrypter.isLoading;

          return ListView.builder(
            itemCount: files.length,
            itemBuilder: (context, index) {
              final file = files[index];
              return ListTile(
                title: Text(file.filename),
                subtitle: Text('Added: ${file.addedAt.toLocal()}'),
                onTap: isDecrypting
                    ? null
                    : () {
                        ref
                            .read(vaultFileDecrypterProvider.notifier)
                            .decryptAndSave(file);
                      },
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: vaultFileSender.isLoading
            ? null
            : () async {
                final service = ref.read(filePickerServiceProvider);
                final result = await service.pickFile();

                if (result != null && result.files.single.path != null) {
                  final path = result.files.single.path;
                  final filename = result.files.single.name;

                  if (path == null) return;

                  ref
                      .read(vaultFileSenderProvider.notifier)
                      .sendFile(path, filename);
                } else {
                  if (context.mounted) {
                    NotificationReporter.reportInfo('File picking canceled');
                  }
                }
              },
        tooltip: 'Add File to Vault',
        child: vaultFileSender.isLoading
            ? const SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(strokeWidth: 3),
              )
            : const Icon(Icons.add),
      ),
    );
  }
}
