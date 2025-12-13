import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:local_sync/src/rust/api/identity.dart';

/// Handles the business logic for creating, importing, and storing
/// the user's master mnemonic phrase.
class MasterKeyService {
  final FlutterSecureStorage _secureStorage;

  static const _masterKeyStorageKey = 'master_key_mnemonic';

  MasterKeyService(this._secureStorage);

  /// Generates a new 24-word (256-bit) BIP39 mnemonic.
  /// This does NOT store the mnemonic.
  Future<String> generateMnemonic() async {
    return generateMnemonicWords();
  }

  /// Validates a given mnemonic phrase.
  Future<bool> validateMnemonic(String mnemonic) {
    return validateMnemonicWords(phrase: mnemonic);
  }

  /// Securely persists the mnemonic to the device's keychain.
  Future<void> storeMnemonic(String mnemonic) async {
    await _secureStorage.write(key: _masterKeyStorageKey, value: mnemonic);
  }

  /// Retrieves the securely stored mnemonic.
  /// Returns null if no mnemonic is stored.
  Future<String?> getMnemonic() async {
    return _secureStorage.read(key: _masterKeyStorageKey);
  }

  /// Checks if a master key is currently stored.
  Future<bool> keyExists() async {
    final key = await getMnemonic();
    return key != null;
  }
}
