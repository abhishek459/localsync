import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:local_sync/features/master_key/data/master_key_providers.dart';

part 'master_key_storer_provider.g.dart';

/// This provider manages the asynchronous state for the *action*
/// of validating and storing a new master key.
@riverpod
class MasterKeyStorer extends _$MasterKeyStorer {
  @override
  Future<void> build() async {
    // This provider is a "notifier" for an action,
    // so its build method is empty.
  }

  /// Attempts to validate and store the given mnemonic phrase.
  /// Handles loading and error states.
  Future<void> storeMnemonic(String mnemonic) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      final service = ref.read(masterKeyServiceProvider);

      // 1. Validate (this is crucial for the import flow)
      if (!service.validateMnemonic(mnemonic)) {
        throw Exception(
          'Invalid mnemonic phrase. Please check the words and try again.',
        );
      }

      // 2. Store the key
      await service.storeMnemonic(mnemonic);

      // 3. Invalidate the 'masterKeyProvider'. This is critical.
      // It tells any part of the app watching 'masterKeyProvider'
      // to re-fetch, which will now find the new key.
      ref.invalidate(masterKeyProvider);
    });
  }
}
