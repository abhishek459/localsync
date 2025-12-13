import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:local_sync/features/identity/application/identity_service.dart';
import 'package:local_sync/features/master_key/data/master_key_providers.dart';
import 'package:local_sync/src/rust/api/identity.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:shared_preferences/shared_preferences.dart';

part 'identity_providers.g.dart';

/// Provides a singleton instance of FlutterSecureStorage.
@Riverpod(keepAlive: true)
FlutterSecureStorage secureStorage(Ref ref) {
  return const FlutterSecureStorage();
}

@Riverpod(keepAlive: true)
Future<SharedPreferences> sharedPreferences(Ref ref) {
  return SharedPreferences.getInstance();
}

/// Provides the IdentityService, injecting dependencies.
@Riverpod(keepAlive: true)
Future<IdentityService> identityService(Ref ref) async {
  final masterKeyService = ref.watch(masterKeyServiceProvider);
  final prefs = await ref.watch(sharedPreferencesProvider.future);
  return IdentityService(masterKeyService, prefs);
}

/// Provides the active Rust NetworkIdentity.
/// This will be null if the user hasn't logged in (no Master Key).
@Riverpod(keepAlive: true)
Future<NetworkIdentity?> networkIdentity(Ref ref) async {
  // Wait for the service to be created (async because of SharedPreferences)
  final service = await ref.watch(identityServiceProvider.future);
  // Initialize the crypto identity
  return service.initIdentity();
}
