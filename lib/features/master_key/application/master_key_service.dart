import 'package:blockchain_utils/blockchain_utils.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Handles the business logic for creating, importing, and storing
/// the user's master mnemonic phrase.
class MasterKeyService {
  final FlutterSecureStorage _secureStorage;

  static const _masterKeyStorageKey = 'master_key_mnemonic';

  MasterKeyService(this._secureStorage);

  /// Generates a new 24-word (256-bit) BIP39 mnemonic.
  /// This does NOT store the mnemonic.
  String generateMnemonic() {
    final mnemonic = Bip39MnemonicGenerator().fromWordsNumber(
      Bip39WordsNum.wordsNum24,
    );
    return mnemonic.toList().join(' ');
  }

  /// Validates a given mnemonic phrase.
  bool validateMnemonic(String mnemonic) {
    return Bip39MnemonicValidator().isValid(mnemonic);
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
