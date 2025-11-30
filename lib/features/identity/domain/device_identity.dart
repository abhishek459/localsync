import 'package:freezed_annotation/freezed_annotation.dart';

part 'device_identity.freezed.dart';

/// A domain entity representing the device's cryptographic identity.
///
/// We store keys in PEM format. The actual key generation and parsing
/// happen in the Rust layer (via FFI).
///
/// NOTE: This class must be 'abstract' or a 'mixin class' to work
/// properly with Freezed mixins without compiler errors.
@freezed
abstract class DeviceIdentity with _$DeviceIdentity {
  const factory DeviceIdentity({
    /// The unique fingerprint of the device (SHA-256 of the certificate).
    /// Used as the primary node ID in the P2P mesh.
    required String deviceId,

    /// The human-readable display name (e.g. "Abhishek's Pixel").
    required String deviceName,

    /// The raw RSA Private Key in PEM format.
    /// ⚠️ SENSITIVE: Never share this over the network.
    required String privateKeyPem,

    /// The X.509 Certificate in PEM format.
    /// This contains the public key and is safe to share during TLS handshakes.
    required String publicCertPem,
  }) = _DeviceIdentity;
}
