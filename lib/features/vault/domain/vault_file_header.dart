import 'dart:convert';
import 'package:flutter/foundation.dart';

/// A data class representing the JSON header sent over the transport protocol
/// for a Secure Vault file.
@immutable
class VaultFileHeader {
  const VaultFileHeader({
    required this.filename,
    required this.nonce,
    required this.mac,
  });

  final String filename;

  /// Base64 encoded 12-byte nonce.
  final String nonce;

  /// Base64 encoded 16-byte MAC.
  final String mac;

  Map<String, dynamic> toMap() {
    return {'filename': filename, 'nonce': nonce, 'mac': mac};
  }

  factory VaultFileHeader.fromMap(Map<String, dynamic> map) {
    return VaultFileHeader(
      filename: map['filename'] as String,
      nonce: map['nonce'] as String,
      mac: map['mac'] as String,
    );
  }

  String toJson() => json.encode(toMap());

  factory VaultFileHeader.fromJson(String source) =>
      VaultFileHeader.fromMap(json.decode(source) as Map<String, dynamic>);
}
