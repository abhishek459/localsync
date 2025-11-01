import 'dart:ffi';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqlite3/sqlite3.dart';
import 'package:sqlite3/open.dart' as sqlite_open;
import 'package:sqlite3_flutter_libs/sqlite3_flutter_libs.dart';

/// Service to initialize and provide the singleton sqlite3 database.
/// This is the low-level service that just opens the DB.
class DatabaseService {
  Database? _db;

  /// Lazily initializes and returns the database.
  Future<Database> get db async {
    if (_db != null) return _db!;
    _db = await _initDb();
    return _db!;
  }

  Future<Database> _initDb() async {
    if (Platform.isAndroid) {
      await applyWorkaroundToOpenSqlite3OnOldAndroidVersions();
    }

    if (Platform.isWindows || Platform.isLinux) {
      sqlite_open.open.overrideFor(
        Platform.isWindows
            ? sqlite_open.OperatingSystem.windows
            : sqlite_open.OperatingSystem.linux,
        _openSqlite3,
      );
    }

    final dbPath = await _getDatabasePath();
    final db = sqlite3.open(dbPath);

    _createTables(db);
    return db;
  }

  /// Finds the correct cross-platform path to store the database file.
  Future<String> _getDatabasePath() async {
    final appDocsDir = await getApplicationDocumentsDirectory();
    final dbPath = p.join(appDocsDir.path, 'local_sync.db');
    return dbPath;
  }

  // FIX: Helper to load the bundled sqlite3.so/dll on desktop.
  // This uses DynamicLibrary (from dart:ffi).
  DynamicLibrary _openSqlite3() {
    if (Platform.isWindows) {
      return DynamicLibrary.open('sqlite3.dll');
    }
    if (Platform.isLinux) {
      return DynamicLibrary.open('libsqlite3.so.0');
    }
    // Other platforms (iOS, macOS, Android) are handled by default
    // by sqlite3_flutter_libs
    return DynamicLibrary.process();
  }

  /// Creates our database schema. This is idempotent and can be run safely
  /// on every app launch.
  void _createTables(Database db) {
    // This is our "VIP List" of trusted peers.
    db.execute('''
      CREATE TABLE IF NOT EXISTS trusted_peers (
        fingerprint TEXT PRIMARY KEY,
        name TEXT NOT NULL,
        trusted_at INTEGER NOT NULL
      );
    ''');

    // --- FUTURE-PROOFING ---
    // We create these tables now so our schema is ready for future features.

    // This is our "snapshot" of all files.
    db.execute('''
      CREATE TABLE IF NOT EXISTS file_index (
        path TEXT PRIMARY KEY,
        hash TEXT,
        modified_at INTEGER,
        synced_with_all_peers INTEGER DEFAULT 0
      );
    ''');

    // This is our "diff log" for sync changes.
    db.execute('''
      CREATE TABLE IF NOT EXISTS sync_log (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        file_path TEXT NOT NULL,
        change_type TEXT NOT NULL, -- 'update' or 'delete'
        timestamp INTEGER NOT NULL
      );
    ''');
  }

  /// Closes the database connection when the service is disposed.
  void dispose() {
    _db?.dispose();
  }
}
