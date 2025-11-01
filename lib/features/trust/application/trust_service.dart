import 'package:local_sync/features/trust/domain/trusted_peer.dart';
import 'package:sqlite3/sqlite3.dart';

/// Repository for managing the `trusted_peers` table in the database.
/// This service contains the business logic for trusting peers.
class TrustService {
  final Database _db;

  TrustService(this._db);

  /// Get all trusted peers from the database.
  Future<List<TrustedPeer>> getTrustedPeers() async {
    final List<TrustedPeer> peers = [];
    // We use `try-finally` to ensure the statement is always disposed.
    final stmt = _db.prepare('SELECT * FROM trusted_peers');
    try {
      final ResultSet resultSet = stmt.select();
      for (final Row row in resultSet) {
        peers.add(TrustedPeer.fromMap(row));
      }
    } finally {
      stmt.dispose();
    }
    return peers;
  }

  /// Add a new peer to the trusted list.
  Future<void> trustPeer(TrustedPeer peer) async {
    final stmt = _db.prepare(
      'INSERT OR REPLACE INTO trusted_peers (fingerprint, name, trusted_at) VALUES (?, ?, ?)',
    );
    try {
      stmt.execute([
        peer.fingerprint,
        peer.name,
        peer.trustedAt.millisecondsSinceEpoch,
      ]);
    } finally {
      stmt.dispose();
    }
  }

  /// Remove a peer from the trusted list.
  Future<void> untrustPeer(String fingerprint) async {
    final stmt = _db.prepare('DELETE FROM trusted_peers WHERE fingerprint = ?');
    try {
      stmt.execute([fingerprint]);
    } finally {
      stmt.dispose();
    }
  }
}
