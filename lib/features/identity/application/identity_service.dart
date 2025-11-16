import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:local_sync/features/identity/domain/device_identity.dart';
import 'package:shared_preferences/shared_preferences.dart';

// Import the new compute functions
import 'identity_service_compute.dart';

/// Handles the creation and persistence of the device's cryptographic identity.
/// All CPU-intensive crypto operations are offloaded to a compute isolate.
class IdentityService {
  final FlutterSecureStorage _secureStorage;
  final SharedPreferences _prefs;

  static const _privateKeyStorageKey = 'device_private_key_pem';
  static const _publicCertStorageKey = 'device_public_cert_pem';

  IdentityService(this._secureStorage, this._prefs);

  /// Gets the existing device identity from storage, or creates a new one
  /// if it doesn't exist.
  Future<DeviceIdentity> getOrCreateIdentity() async {
    // Reading from storage is I/O, not CPU-bound, so it's fine.
    final privateKeyPem = await _secureStorage.read(key: _privateKeyStorageKey);
    final publicCertPem = _prefs.getString(_publicCertStorageKey);

    if (privateKeyPem != null && publicCertPem != null) {
      try {
        // --- LOAD FROM PEM IN ISOLATE ---
        return await compute(computeLoadFromPem, {
          'private': privateKeyPem,
          'public': publicCertPem,
        });
      } catch (e) {
        // If parsing fails (e.g., corrupt data), generate a new one.
        return _createNewIdentity(forceDelete: true);
      }
    } else {
      // --- CREATE NEW IDENTITY IN ISOLATE ---
      return _createNewIdentity();
    }
  }

  /// Generates a new RSA-4096 keypair and a self-signed X.509 certificate
  /// by calling a compute isolate, then persists the results.
  Future<DeviceIdentity> _createNewIdentity({bool forceDelete = false}) async {
    if (forceDelete) {
      await _secureStorage.delete(key: _privateKeyStorageKey);
      await _prefs.remove(_publicCertStorageKey);
    }

    // --- RUN GENERATION IN ISOLATE ---
    final result = await compute(computeCreateNewIdentity, null);

    // --- SAVE RESULTS ---
    await _secureStorage.write(
      key: _privateKeyStorageKey,
      value: result.privateKeyPem,
    );
    await _prefs.setString(_publicCertStorageKey, result.publicCertPem);

    return result.identity;
  }
}
