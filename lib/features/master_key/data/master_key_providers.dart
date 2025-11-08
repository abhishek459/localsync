import 'package:blockchain_utils/blockchain_utils.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:local_sync/features/identity/data/identity_providers.dart';
import 'package:local_sync/features/master_key/application/master_key_service.dart';

part 'master_key_providers.g.dart';

/// Provides the singleton instance of the [MasterKeyService],
/// injecting its [FlutterSecureStorage] dependency.
@riverpod
MasterKeyService masterKeyService(Ref ref) {
  final secureStorage = ref.watch(secureStorageProvider);
  return MasterKeyService(secureStorage);
}

/// A provider that asynchronously retrieves the stored master key mnemonic.
///
/// This will be the primary provider used by the app to determine if a
/// master key exists and to route the user accordingly.
///
/// It will return `String?`:
/// - `null`: No key is stored.
/// - `String`: The mnemonic is present.
@riverpod
Future<String?> masterKey(Ref ref) {
  final service = ref.watch(masterKeyServiceProvider);
  return service.getMnemonic();
}

/// Derives a 32-byte AES key from the master mnemonic.
///
/// This key is the single, deterministic encryption key for the
/// entire Secure Vault.
///
/// It follows the BIP32 derivation path: m/44'/999'/0'/0/0
/// (We use 999' for LocalSync to avoid collisions with coin types).
@riverpod
Future<List<int>> vaultAesKey(Ref ref) async {
  // 1. Get the stored mnemonic
  final mnemonic = await ref.watch(masterKeyProvider.future);
  if (mnemonic == null) {
    throw Exception('Cannot derive AES key: No master key is stored.');
  }

  // 2. Convert mnemonic string back to a Mnemonic object
  final mnemonicObj = Mnemonic.fromString(mnemonic);

  // 3. Convert mnemonic to a 64-byte seed
  final seed = Bip39SeedGenerator(mnemonicObj).generate();

  // 4. Create a Bip32 master node from the seed
  final bip32 = Bip32Slip10Secp256k1.fromSeed(seed);

  // 5. Define our app-specific, hardened derivation path
  // m/44' (BIP44) / 999' (LocalSync App) / 0' (Vault Feature) / 0 (Key Index)
  final childKey = bip32
      .derivePath("m/44'/999'/0'/0/0")
      .privateKey
      .raw; // Get the raw 32-byte key

  return childKey;
}
