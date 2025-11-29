import 'package:local_sync/features/vault/application/encryption_service.dart';
import 'package:path_provider/path_provider.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:path/path.dart' as p;
import 'package:local_sync/features/vault/domain/vault_file_metadata.dart';

part 'vault_file_decrypter_provider.g.dart';

@riverpod
class VaultFileDecrypter extends _$VaultFileDecrypter {
  @override
  Future<String?> build() async {
    return null;
  }

  Future<void> decryptAndSave(VaultFileMetadata fileMeta) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      final encryptionService = await ref.read(
        encryptionServiceProvider.future,
      );

      // Determine where to save the decrypted file (Downloads folder)
      final downloadsDir = await getDownloadsDirectory();
      if (downloadsDir == null) {
        throw Exception('Could not find downloads directory.');
      }
      final savePath = p.join(downloadsDir.path, fileMeta.filename);

      // Call the service to stream-decrypt from vault storage directly to Downloads.
      // We no longer read bytes into memory here.
      await encryptionService.decryptFile(
        inputPath: fileMeta.ciphertextPath,
        outputPath: savePath,
        nonce: fileMeta.nonce,
      );

      return savePath;
    });
  }
}
