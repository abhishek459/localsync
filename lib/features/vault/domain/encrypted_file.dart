import 'package:flutter/foundation.dart';

/// A data class to hold the components of an encrypted file.
/// This is necessary because AES-GCM encryption returns the ciphertext,
/// a nonce (IV), and a MAC (authentication tag) as separate parts.
@immutable
class EncryptedFile {
  const EncryptedFile({
    required this.nonce,
    required this.mac,
    required this.ciphertext,
  });

  /// The 12-byte nonce (or "initialization vector").
  /// This must be unique for every encryption with the same key.
  final List<int> nonce;

  /// The 16-byte "message authentication code" (MAC).
  /// This ensures the ciphertext has not been tampered with.
  final List<int> mac;

  /// The encrypted file content.
  final Uint8List ciphertext;
}
