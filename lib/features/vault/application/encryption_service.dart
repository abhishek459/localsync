import 'dart:io';
import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';
import 'package:local_sync/features/vault/domain/encrypted_file.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:local_sync/features/master_key/data/master_key_providers.dart';

part 'encryption_service.g.dart';

/// Provides high-level methods for encrypting and decrypting files
/// for the Secure Vault.
class EncryptionService {
  final SecretKey _vaultKey;
  final _algorithm = AesGcm.with256bits();

  EncryptionService(this._vaultKey);

  /// Encrypts a file at the given [filePath].
  ///
  /// This reads the file, generates a new random 12-byte nonce,
  /// and encrypts the content using AES-256-GCM.
  Future<EncryptedFile> encryptFile(String filePath) async {
    final fileBytes = await File(filePath).readAsBytes();
    final nonce = _algorithm.newNonce();

    final secretBox = await _algorithm.encrypt(
      fileBytes,
      secretKey: _vaultKey,
      nonce: nonce,
    );

    return EncryptedFile(
      nonce: secretBox.nonce,
      mac: secretBox.mac.bytes,
      ciphertext: Uint8List.fromList(secretBox.cipherText),
    );
  }

  /// Decrypts a [EncryptedFile] object.
  ///
  /// This re-combines the ciphertext, nonce, and MAC into a [SecretBox]
  /// and attempts to decrypt it with the vault key. It will throw an
  /// error if the key is incorrect or the data has been tampered with.
  Future<Uint8List> decryptFile(EncryptedFile encryptedFile) async {
    final secretBox = SecretBox(
      encryptedFile.ciphertext,
      nonce: encryptedFile.nonce,
      mac: Mac(encryptedFile.mac),
    );

    final decryptedBytes = await _algorithm.decrypt(
      secretBox,
      secretKey: _vaultKey,
    );

    return Uint8List.fromList(decryptedBytes);
  }
}

/// Derives the 32-byte AES key from the master mnemonic and provides the
/// singleton [EncryptionService].
@riverpod
Future<EncryptionService> encryptionService(Ref ref) async {
  // 1. Get the 32-byte AES key derived from the master key.
  final vaultKey = await ref.watch(vaultAesKeyProvider.future);

  // 2. Create the SecretKey object required by the cryptography package.
  final secretKey = SecretKey(vaultKey);

  // 3. Return the service instance.
  return EncryptionService(secretKey);
}
