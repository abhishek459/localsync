import 'dart:io';

import 'package:local_sync/features/trust/data/trust_providers.dart';
import 'package:local_sync/features/vault/domain/vault_file_metadata.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:sqlite3/sqlite3.dart';

part 'vault_repository.g.dart';

/// Manages the database and file system storage for Secure Vault files.
class VaultRepository {
  final Database _db;
  final Directory _vaultDataDir;

  VaultRepository(this._db, this._vaultDataDir);

  Future<void> addFile({
    required String id,
    required String filename,
    required List<int> nonce,
    required String ciphertextPath,
  }) async {
    // 1. Ensure the vault data directory exists
    if (!_vaultDataDir.existsSync()) {
      _vaultDataDir.createSync(recursive: true);
    }

    // 2. Save the metadata to the database
    // We explicitly insert ciphertext_path so we can find the file later.
    final stmt = _db.prepare(
      'INSERT INTO secure_vault (id, filename, nonce, ciphertext_path, added_at) '
      'VALUES (?, ?, ?, ?, ?)',
    );
    try {
      stmt.execute([
        id,
        filename,
        nonce,
        ciphertextPath,
        DateTime.now().millisecondsSinceEpoch,
      ]);
    } finally {
      stmt.dispose();
    }
  }

  /// Retrieves all file metadata records from the database.
  Future<List<VaultFileMetadata>> getFiles() async {
    final List<VaultFileMetadata> files = [];
    final stmt = _db.prepare('SELECT * FROM secure_vault');
    try {
      final ResultSet resultSet = stmt.select();
      for (final Row row in resultSet) {
        files.add(VaultFileMetadata.fromMap(row));
      }
    } finally {
      stmt.dispose();
    }
    return files;
  }
}

/// Provides the application's document directory.
@riverpod
Future<Directory> appDocumentsDirectory(Ref ref) {
  return getApplicationDocumentsDirectory();
}

/// Provides the singleton [VaultRepository].
@riverpod
Future<VaultRepository> vaultRepository(Ref ref) async {
  final db = await ref.watch(databaseProvider.future);
  final appDocsDir = await ref.watch(appDocumentsDirectoryProvider.future);

  // We create a dedicated, non-user-facing directory for encrypted blobs
  final vaultDataDir = Directory(p.join(appDocsDir.path, 'SecureVaultData'));

  return VaultRepository(db, vaultDataDir);
}

/// Provides the reactive list of vault files.
@riverpod
Future<List<VaultFileMetadata>> vaultFiles(Ref ref) async {
  final repository = await ref.watch(vaultRepositoryProvider.future);
  return repository.getFiles();
}
