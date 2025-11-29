import 'package:flutter/foundation.dart';

@immutable
class VaultFileMetadata {
  const VaultFileMetadata({
    required this.id,
    required this.filename,
    required this.nonce,
    required this.ciphertextPath,
    required this.addedAt,
  });

  final String id;
  final String filename;

  /// The raw 24-byte nonce.
  final List<int> nonce;

  /// The absolute path to the encrypted ciphertext file on this device.
  final String ciphertextPath;
  final DateTime addedAt;

  factory VaultFileMetadata.fromMap(Map<String, dynamic> map) {
    return VaultFileMetadata(
      id: map['id'] as String,
      filename: map['filename'] as String,
      nonce: map['nonce'] as List<int>,
      ciphertextPath: map['ciphertext_path'] as String,
      addedAt: DateTime.fromMillisecondsSinceEpoch(map['added_at'] as int),
    );
  }
}
