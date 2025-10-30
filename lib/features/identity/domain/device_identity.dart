import 'package:basic_utils/basic_utils.dart';

/// A data class holding the cryptographic identity of this device.
class DeviceIdentity {
  /// The RSA private key.
  final RSAPrivateKey privateKey;

  /// The self-signed X.509 certificate containing the public key.
  /// This is the X509CertificateData object from basic_utils.
  final X509CertificateData certificate;

  /// The unique ID for this device (the SHA-256 fingerprint of the certificate).
  final String fingerprint;

  DeviceIdentity({
    required this.privateKey,
    required this.certificate,
    required this.fingerprint,
  });
}
