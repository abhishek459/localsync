import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:local_sync/features/identity/application/identity_service.dart';
import 'package:local_sync/features/identity/domain/device_identity.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Provider for the secure storage instance.
final secureStorageProvider = Provider((_) => const FlutterSecureStorage());

/// The main provider for the device's cryptographic identity.
///
/// This provider handles initializing all dependencies (secure storage, prefs)
/// and then uses the [IdentityService] to get or create the identity.
final deviceIdentityProvider = FutureProvider<DeviceIdentity>((ref) async {
  final secureStorage = ref.watch(secureStorageProvider);

  // SharedPreferences is async, so we must await it.
  final prefs = await SharedPreferences.getInstance();

  // Instantiate the service with its dependencies.
  final service = IdentityService(secureStorage, prefs);

  // Get or create the identity.
  return service.getOrCreateIdentity();
});
