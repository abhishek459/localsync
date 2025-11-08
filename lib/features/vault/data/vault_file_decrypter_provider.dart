import 'dart:io';

import 'package:local_sync/features/vault/application/encryption_service.dart';
import 'package:local_sync/features/vault/domain/encrypted_file.dart';
import 'package:local_sync/features/vault/domain/vault_file_metadata.dart';
import 'package:path_provider/path_provider.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:path/path.dart' as p;

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

      final ciphertext = await File(fileMeta.ciphertextPath).readAsBytes();

      final encryptedFile = EncryptedFile(
        nonce: fileMeta.nonce,
        mac: fileMeta.mac,
        ciphertext: ciphertext,
      );

      final decryptedBytes = await encryptionService.decryptFile(encryptedFile);

      final downloadsDir = await getDownloadsDirectory();
      if (downloadsDir == null) {
        throw Exception('Could not find downloads directory.');
      }

      final savePath = p.join(downloadsDir.path, fileMeta.filename);
      await File(savePath).writeAsBytes(decryptedBytes);

      return savePath;
    });
  }
}
