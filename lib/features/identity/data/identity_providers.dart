import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:local_sync/features/identity/application/identity_service.dart';
import 'package:local_sync/features/identity/domain/device_identity.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:shared_preferences/shared_preferences.dart';

part 'identity_providers.g.dart';

/// Provides a singleton instance of FlutterSecureStorage.
@Riverpod(keepAlive: true)
FlutterSecureStorage secureStorage(Ref ref) {
  return const FlutterSecureStorage();
}

/// Provides the SharedPreferences instance asynchronously.
@Riverpod(keepAlive: true)
Future<SharedPreferences> sharedPreferences(Ref ref) {
  return SharedPreferences.getInstance();
}

/// Provides the main DeviceIdentity object for the app.
///
/// This provider handles all asynchronous initialization and provides a
/// clean AsyncValue (loading, data, error) to the UI.
@Riverpod(keepAlive: true)
Future<DeviceIdentity> deviceIdentity(Ref ref) async {
  // We depend on SharedPreferences being ready.
  final prefs = await ref.watch(sharedPreferencesProvider.future);
  // We also depend on secure storage (which is synchronous).
  final secureStorage = ref.watch(secureStorageProvider);

  // Once dependencies are ready, create the service.
  final service = IdentityService(secureStorage, prefs);

  // Get or create the identity. This is the main async work.
  return service.getOrCreateIdentity();
}
