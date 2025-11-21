import 'dart:io';
import 'dart:isolate';
import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';
import 'package:local_sync/features/vault/domain/encrypted_file.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:local_sync/features/master_key/data/master_key_providers.dart';

part 'encryption_service.g.dart';

/// Provides high-level methods for encrypting and decrypting files
/// for the Secure Vault using background isolates to prevent UI blocking.
class EncryptionService {
  // We store the raw bytes because we need to send them to the Isolate.
  // Complex objects like SecretKey might not be sendable depending on implementation.
  final List<int> _keyBytes;

  EncryptionService(this._keyBytes);

  /// Encrypts a file at the given [filePath] in a background isolate.
  ///
  /// 1. Spawns an isolate.
  /// 2. Reads the file inside the isolate (preventing I/O jank).
  /// 3. Encrypts content using AES-256-GCM.
  /// 4. Returns the result to the main thread.
  Future<EncryptedFile> encryptFile(String filePath) async {
    // Capture the key bytes to pass to the isolate closure
    final keyBytes = _keyBytes;

    return await Isolate.run(() async {
      // --- Everything here runs on a background thread ---

      // 1. Perform File I/O in the isolate
      final file = File(filePath);
      if (!file.existsSync()) {
        throw FileSystemException("File not found", filePath);
      }
      final fileBytes = await file.readAsBytes();

      // 2. Setup Algo
      final algorithm = AesGcm.with256bits();
      final secretKey = SecretKey(keyBytes);
      final nonce = algorithm.newNonce();

      // 3. Encrypt
      final secretBox = await algorithm.encrypt(
        fileBytes,
        secretKey: secretKey,
        nonce: nonce,
      );

      // 4. Return the result
      // EncryptedFile must be a simple data class (sendable)
      return EncryptedFile(
        nonce: secretBox.nonce,
        mac: secretBox.mac.bytes,
        ciphertext: Uint8List.fromList(secretBox.cipherText),
      );
    });
  }

  /// Decrypts a [EncryptedFile] object in a background isolate.
  Future<Uint8List> decryptFile(EncryptedFile encryptedFile) async {
    final keyBytes = _keyBytes;

    return await Isolate.run(() async {
      // --- Everything here runs on a background thread ---

      final algorithm = AesGcm.with256bits();
      final secretKey = SecretKey(keyBytes);

      final secretBox = SecretBox(
        encryptedFile.ciphertext,
        nonce: encryptedFile.nonce,
        mac: Mac(encryptedFile.mac),
      );

      final decryptedBytes = await algorithm.decrypt(
        secretBox,
        secretKey: secretKey,
      );

      return Uint8List.fromList(decryptedBytes);
    });
  }
}

/// Derives the 32-byte AES key from the master mnemonic and provides the
/// singleton [EncryptionService].
@riverpod
Future<EncryptionService> encryptionService(Ref ref) async {
  // 1. Get the 32-byte AES key derived from the master key.
  // We assume this provider returns a List<int> or Uint8List.
  final vaultKey = await ref.watch(vaultAesKeyProvider.future);

  // 2. Pass the raw bytes to the service.
  // We do NOT create the SecretKey object here anymore, as we need
  // the raw bytes to pass into the Isolate.
  return EncryptionService(vaultKey);
}
