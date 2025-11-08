import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
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
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to send file: ${next.error}'),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
      if (prev is AsyncLoading && next is AsyncData) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('File added to vault and broadcasted!'),
            backgroundColor: Colors.green,
          ),
        );
      }
    });

    ref.listen(vaultFileDecrypterProvider, (prev, next) {
      if (next is AsyncLoading) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Decrypting and saving...')),
        );
      }
      if (next is AsyncError) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to decrypt file: ${next.error}'),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
      if (prev is AsyncLoading && next is AsyncData<String?>) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('File saved to Downloads! (${next.value})'),
            backgroundColor: Colors.green,
          ),
        );
      }
    });

    return Scaffold(
      appBar: AppBar(title: const Text('Secure Vault')),
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
            return const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.info_outline, size: 48, color: Colors.grey),
                  SizedBox(height: 16),
                  Text('Your Secure Vault is empty'),
                  Text(
                    'Tap the "+" button to add a file.',
                    style: TextStyle(color: Colors.grey),
                  ),
                ],
              ),
            );
          }

          final bool isDecrypting = vaultFileDecrypter.isLoading;

          return ListView.builder(
            itemCount: files.length,
            itemBuilder: (context, index) {
              final file = files[index];
              return ListTile(
                leading: const Icon(Icons.lock_outline),
                title: Text(file.filename),
                subtitle: Text('Added: ${file.addedAt.toLocal()}'),
                trailing: const Icon(Icons.download_for_offline_outlined),
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
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('File picking canceled')),
                    );
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
