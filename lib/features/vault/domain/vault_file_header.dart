import 'dart:convert';
import 'package:flutter/foundation.dart';

@immutable
class VaultFileHeader {
  const VaultFileHeader({required this.filename, required this.nonce});

  final String filename;

  /// Base64 encoded 24-byte nonce.
  final String nonce;

  Map<String, dynamic> toMap() {
    return {'filename': filename, 'nonce': nonce};
  }

  factory VaultFileHeader.fromMap(Map<String, dynamic> map) {
    return VaultFileHeader(
      filename: map['filename'] as String,
      nonce: map['nonce'] as String,
    );
  }

  String toJson() => json.encode(toMap());

  factory VaultFileHeader.fromJson(String source) =>
      VaultFileHeader.fromMap(json.decode(source) as Map<String, dynamic>);
}
