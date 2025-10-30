import 'package:basic_utils/basic_utils.dart';

/// A data class holding the cryptographic identity of this device.
class DeviceIdentity {
  /// The parsed RSA private key object.
  final RSAPrivateKey? privateKey;

  /// The raw PEM-formatted string for the private key.
  final String? privateKeyPem;

  /// The parsed X.509 certificate object.
  /// This contains all certificate data, including validity,
  /// subject, and the SHA-256 thumbprint.
  /// It also contains the raw PEM string in its `.plain` property.
  final X509CertificateData? certificate;

  /// The unique SHA-256 fingerprint, lowercase, no colons.
  /// This is our canonical "Device ID".
  final String fingerprint;

  const DeviceIdentity({
    required this.privateKey,
    required this.privateKeyPem,
    required this.certificate,
    required this.fingerprint,
  });

  /// An "empty" identity for initial loading states.
  static const DeviceIdentity empty = DeviceIdentity(
    privateKey: null,
    privateKeyPem: null,
    certificate: null,
    fingerprint: '',
  );

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;

    return other is DeviceIdentity &&
        other.privateKey == privateKey &&
        other.privateKeyPem == privateKeyPem &&
        other.certificate == certificate &&
        other.fingerprint == fingerprint;
  }

  @override
  int get hashCode {
    return privateKey.hashCode ^
        privateKeyPem.hashCode ^
        certificate.hashCode ^
        fingerprint.hashCode;
  }
}
