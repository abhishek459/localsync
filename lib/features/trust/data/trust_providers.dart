import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:local_sync/features/pairing/domain/pairing_data.dart';
import 'package:local_sync/features/trust/application/database_service.dart';
import 'package:local_sync/features/trust/application/trust_service.dart';
import 'package:local_sync/features/trust/domain/trusted_peer.dart';
import 'package:sqlite3/sqlite3.dart';

/// Provider for the singleton DatabaseService.
final databaseServiceProvider = Provider<DatabaseService>((ref) {
  final dbService = DatabaseService();
  ref.onDispose(() => dbService.dispose());
  return dbService;
});

/// Asynchronously provides the opened [Database] object.
/// Other services will watch this.
final databaseProvider = FutureProvider<Database>((ref) {
  final dbService = ref.watch(databaseServiceProvider);
  return dbService.db;
});

/// Provider for the singleton TrustService (Repository).
final trustServiceProvider = Provider<TrustService>((ref) {
  // This provider will either get the DB or throw an error
  // if it's not ready, which is what we want.
  final db = ref.watch(databaseProvider).requireValue;
  return TrustService(db);
});

/// This is the reactive, in-memory "VIP List" for the whole app.
///
/// It's the "single source of truth" for who we trust.
final trustListProvider =
    AsyncNotifierProvider<TrustListNotifier, List<TrustedPeer>>(
      TrustListNotifier.new,
    );

class TrustListNotifier extends AsyncNotifier<List<TrustedPeer>> {
  @override
  Future<List<TrustedPeer>> build() async {
    // Load the initial list of peers from the database
    final trustService = ref.watch(trustServiceProvider);
    return trustService.getTrustedPeers();
  }

  /// Adds a new peer (from QR scan data) to the database and refreshes the state.
  Future<void> addPeerFromPairingData(PairingData data, String peerName) async {
    final trustService = ref.read(trustServiceProvider);
    final peer = TrustedPeer(
      fingerprint: data.fingerprint,
      name: peerName, // We can get this from the QR or cert
      trustedAt: DateTime.now(),
    );

    // Update the DB
    await trustService.trustPeer(peer);

    // Re-fetch the list from the DB to update our state
    ref.invalidateSelf();
    await future;
  }

  /// Adds a new peer (from a certificate) to the database and refreshes the state.
  Future<void> addPeerFromCertificate(
    String fingerprint,
    String peerName,
  ) async {
    final trustService = ref.read(trustServiceProvider);
    final peer = TrustedPeer(
      fingerprint: fingerprint,
      name: peerName,
      trustedAt: DateTime.now(),
    );
    await trustService.trustPeer(peer);
    ref.invalidateSelf();
    await future;
  }

  /// Removes a peer from the database and refreshes the state.
  Future<void> removePeer(String fingerprint) async {
    final trustService = ref.read(trustServiceProvider);

    // Update the DB
    await trustService.untrustPeer(fingerprint);

    // Re-fetch the list from the DB to update our state
    ref.invalidateSelf();
    await future;
  }
}
