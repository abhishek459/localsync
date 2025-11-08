import 'package:flutter/foundation.dart';

/// A data model for a Secure Vault file stored in the local database.
@immutable
class VaultFileMetadata {
  const VaultFileMetadata({
    required this.id,
    required this.filename,
    required this.nonce,
    required this.mac,
    required this.ciphertextPath,
    required this.addedAt,
  });

  /// A unique ID for the database entry (e.g., UUID).
  final String id;
  final String filename;

  /// The raw 12-byte nonce.
  final List<int> nonce;

  /// The raw 16-byte MAC.
  final List<int> mac;

  /// The absolute path to the encrypted ciphertext file on this device.
  final String ciphertextPath;
  final DateTime addedAt;

  factory VaultFileMetadata.fromMap(Map<String, dynamic> map) {
    return VaultFileMetadata(
      id: map['id'] as String,
      filename: map['filename'] as String,
      // BLOB data is read as List<int>
      nonce: map['nonce'] as List<int>,
      mac: map['mac'] as List<int>,
      ciphertextPath: map['ciphertext_path'] as String,
      addedAt: DateTime.fromMillisecondsSinceEpoch(map['added_at'] as int),
    );
  }
}
