import 'dart:convert';
import 'package:flutter/foundation.dart';

/// A simple, serializable model for QR code data.
/// This is the "payload" we send in the QR code.
@immutable
class PairingData {
  final String ip;
  final int port;
  final String fingerprint;

  const PairingData({
    required this.ip,
    required this.port,
    required this.fingerprint,
  });

  Map<String, dynamic> toMap() {
    return {'ip': ip, 'port': port, 'fingerprint': fingerprint};
  }

  factory PairingData.fromMap(Map<String, dynamic> map) {
    return PairingData(
      ip: map['ip'] as String,
      port: map['port'] as int,
      fingerprint: map['fingerprint'] as String,
    );
  }

  String toJson() => json.encode(toMap());

  factory PairingData.fromJson(String source) =>
      PairingData.fromMap(json.decode(source) as Map<String, dynamic>);
}
