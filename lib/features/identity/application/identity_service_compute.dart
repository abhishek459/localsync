import 'dart:math';
import 'package:basic_utils/basic_utils.dart';
import 'package:local_sync/features/identity/domain/device_identity.dart';

// --- Data class for compute_create ---
// We use this to return multiple values from the isolate.
class ComputeIdentityResult {
  final DeviceIdentity identity;
  final String privateKeyPem;
  final String publicCertPem;

  ComputeIdentityResult({
    required this.identity,
    required this.privateKeyPem,
    required this.publicCertPem,
  });
}

// --- Top-level function for compute() ---
// This runs in the background isolate to create a new identity.
Future<ComputeIdentityResult> computeCreateNewIdentity(dynamic _) async {
  // 1. Generate RSA keypair (This is the heavy part)
  final keyPair = CryptoUtils.generateRSAKeyPair(keySize: 4096);
  final rsaPrivateKey = keyPair.privateKey as RSAPrivateKey;
  final rsaPublicKey = keyPair.publicKey as RSAPublicKey;

  // 2. Generate self-signed certificate PEM string
  final publicCertPem = _computeGenerateSelfSignedCertPem(
    rsaPrivateKey,
    rsaPublicKey,
  );

  // 3. Encode private key to PEM format
  final privateKeyPem = CryptoUtils.encodeRSAPrivateKeyToPem(rsaPrivateKey);

  // 4. Parse the PEMs we just created to get the full objects
  //    and the calculated fingerprint.
  final certificate = X509Utils.x509CertificateFromPem(publicCertPem);
  final fingerprint = certificate.sha256Thumbprint!
      .replaceAll(':', '')
      .toLowerCase();

  // Note: We parse the private key from the PEM we just made.
  // This seems redundant, but it ensures the RSAPrivateKey object is
  // constructed in the same way as it will be when loaded from storage.
  final privateKey = CryptoUtils.rsaPrivateKeyFromPem(privateKeyPem);

  // 5. Create the identity object
  final identity = DeviceIdentity(
    privateKey: privateKey,
    privateKeyPem: privateKeyPem,
    certificate: certificate,
    fingerprint: fingerprint,
  );

  // 6. Return all results to the main thread
  return ComputeIdentityResult(
    identity: identity,
    privateKeyPem: privateKeyPem,
    publicCertPem: publicCertPem,
  );
}

// --- Top-level function for compute() ---
// This runs in the background isolate to load an existing identity.
Future<DeviceIdentity> computeLoadFromPem(Map<String, String> pems) async {
  final privateKeyPem = pems['private']!;
  final publicCertPem = pems['public']!;

  // Parse keys (This is also CPU-intensive)
  final privateKey = CryptoUtils.rsaPrivateKeyFromPem(privateKeyPem);
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
}

/// Helper to generate the self-signed X.509 certificate PEM string.
/// This is a top-level function so computeCreateNewIdentity can use it.
String _computeGenerateSelfSignedCertPem(
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
    cA: true,
  );
}
