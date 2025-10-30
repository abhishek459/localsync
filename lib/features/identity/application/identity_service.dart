import 'dart:math';

import 'package:basic_utils/basic_utils.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:local_sync/features/identity/domain/device_identity.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Handles the creation and persistence of the device's cryptographic identity.
class IdentityService {
  final FlutterSecureStorage _secureStorage;
  final SharedPreferences _prefs;

  static const _privateKeyStorageKey = 'device_private_key_pem';
  static const _publicCertStorageKey = 'device_public_cert_pem';

  IdentityService(this._secureStorage, this._prefs);

  /// Gets the existing device identity from storage, or creates a new one
  /// if it doesn't exist.
  Future<DeviceIdentity> getOrCreateIdentity() async {
    final privateKeyPem = await _secureStorage.read(key: _privateKeyStorageKey);
    final publicCertPem = _prefs.getString(_publicCertStorageKey);

    if (privateKeyPem != null && publicCertPem != null) {
      // Add await here as _loadFromPem is now async
      return await _loadFromPem(privateKeyPem, publicCertPem);
    } else {
      return _createNewIdentity();
    }
  }

  /// Loads an existing identity from PEM-formatted strings.
  // Change return type to Future<DeviceIdentity> and add async
  Future<DeviceIdentity> _loadFromPem(
    String privateKeyPem,
    String publicCertPem,
  ) async {
    try {
      final privateKey = CryptoUtils.rsaPrivateKeyFromPem(privateKeyPem);
      // Parsing from PEM populates the thumbprint properties.
      final certificate = X509Utils.x509CertificateFromPem(publicCertPem);
      final fingerprint = certificate.sha256Thumbprint!
          .replaceAll(':', '')
          .toLowerCase();

      return DeviceIdentity(
        privateKey: privateKey,
        privateKeyPem: privateKeyPem,
        certificate: certificate,
        fingerprint: fingerprint,
      );
    } catch (e) {
      // If loading fails (e.g., corrupt data), we must generate a new one.
      // Add await here
      return await _createNewIdentity(forceDelete: true);
    }
  }

  /// Generates a new RSA-2048 keypair and a self-signed X.509 certificate.
  /// Persists the new identity securely.
  Future<DeviceIdentity> _createNewIdentity({bool forceDelete = false}) async {
    if (forceDelete) {
      await _secureStorage.delete(key: _privateKeyStorageKey);
      await _prefs.remove(_publicCertStorageKey);
    }

    // 1. Generate RSA keypair
    final keyPair = CryptoUtils.generateRSAKeyPair(keySize: 2048);
    final rsaPrivateKey = keyPair.privateKey as RSAPrivateKey;
    final rsaPublicKey = keyPair.publicKey as RSAPublicKey;

    // 2. Generate self-signed certificate PEM string
    final publicCertPem = _generateSelfSignedCertPem(
      rsaPrivateKey,
      rsaPublicKey,
    );

    // 3. Encode private key to PEM format for storage
    final privateKeyPem = CryptoUtils.encodeRSAPrivateKeyToPem(rsaPrivateKey);

    // 4. Store securely
    await _secureStorage.write(
      key: _privateKeyStorageKey,
      value: privateKeyPem,
    );
    await _prefs.setString(_publicCertStorageKey, publicCertPem);

    // 5. Parse the PEM we just created to get the full X509Data object
    //    and its calculated fingerprint.
    final certificate = X509Utils.x509CertificateFromPem(publicCertPem);
    final fingerprint = certificate.sha256Thumbprint!
        .replaceAll(':', '')
        .toLowerCase();

    return DeviceIdentity(
      privateKey: rsaPrivateKey,
      privateKeyPem: privateKeyPem,
      certificate: certificate,
      fingerprint: fingerprint,
    );
  }

  /// Helper to generate the self-signed X.509 certificate PEM string.
  /// This now follows the correct flow: Keys -> CSR -> Certificate
  String _generateSelfSignedCertPem(
    RSAPrivateKey privateKey,
    RSAPublicKey publicKey,
  ) {
    final subject = {'CN': 'LocalSync Device', 'O': 'LocalSync'};
    final issuer = subject; // Self-signed
    final serialNumber = BigInt.from(
      Random().nextInt(999999) + 100000,
    ).toString();
    final validFrom = DateTime.now().toUtc().subtract(const Duration(days: 1));
    const int days = 365 * 10; // 10 years

    // 1. Generate a CSR PEM string
    final csrPem = X509Utils.generateRsaCsrPem(subject, privateKey, publicKey);

    // 2. Use the CSR to generate the self-signed certificate PEM string
    return X509Utils.generateSelfSignedCertificate(
      privateKey,
      csrPem,
      days,
      issuer: issuer,
      notBefore: validFrom,
      serialNumber: serialNumber,
    );
  }
}
