import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:local_sync/features/identity/application/identity_service.dart';
import 'package:local_sync/features/identity/domain/device_identity.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Provides a singleton instance of FlutterSecureStorage.
final secureStorageProvider = Provider((_) => const FlutterSecureStorage());

/// Provides the SharedPreferences instance asynchronously.
final sharedPreferencesProvider = FutureProvider(
  (ref) => SharedPreferences.getInstance(),
);

/// Provides the main DeviceIdentity object for the app.
///
/// This provider handles all asynchronous initialization and provides a
/// clean AsyncValue (loading, data, error) to the UI.
final deviceIdentityProvider = FutureProvider<DeviceIdentity>((ref) async {
  // We depend on SharedPreferences being ready.
  final prefs = await ref.watch(sharedPreferencesProvider.future);
  // We also depend on secure storage (which is synchronous).
  final secureStorage = ref.watch(secureStorageProvider);

  // Once dependencies are ready, create the service.
  final service = IdentityService(secureStorage, prefs);

  // Get or create the identity. This is the main async work.
  return service.getOrCreateIdentity();
});
