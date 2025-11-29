import 'package:local_sync/features/master_key/data/master_key_providers.dart';
import 'package:local_sync/features/vault/domain/encrypted_file.dart';
import 'package:local_sync/src/rust/api/vault.dart';
// Import your generated Rust bridge
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'encryption_service.g.dart';

class EncryptionService {
  final List<int> _keyBytes;

  EncryptionService(this._keyBytes);

  /// Stream-encrypts [inputPath] to [outputPath] using Rust.
  /// Returns the Nonce and the Output Path.
  Future<EncryptedFile> encryptFile({
    required String inputPath,
    required String outputPath,
  }) async {
    // Calls the Rust function 'encrypt_file_stream'
    // This runs on a separate thread pool automatically.
    final result = await encryptFileStream(
      inputPath: inputPath,
      outputPath: outputPath,
      keyBytes: _keyBytes,
    );

    return EncryptedFile(nonce: result.nonce, outputPath: outputPath);
  }

  /// Stream-decrypts [inputPath] to [outputPath] using Rust.
  Future<void> decryptFile({
    required String inputPath,
    required String outputPath,
    required List<int> nonce,
  }) async {
    await decryptFileStream(
      inputPath: inputPath,
      outputPath: outputPath,
      nonceBytes: nonce,
      keyBytes: _keyBytes,
    );
  }
}

@riverpod
Future<EncryptionService> encryptionService(Ref ref) async {
  final vaultKey = await ref.watch(vaultAesKeyProvider.future);
  return EncryptionService(vaultKey);
}
