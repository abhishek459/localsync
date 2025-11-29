import 'package:flutter/foundation.dart';

@immutable
class EncryptedFile {
  const EncryptedFile({required this.nonce, required this.outputPath});

  /// The 24-byte XChaCha20 nonce (Base Nonce).
  final List<int> nonce;

  /// The path to the encrypted file on disk.
  /// We store the path instead of the bytes to save RAM.
  final String outputPath;
}
