import 'dart:async';
import 'package:local_sync/features/pairing/domain/pairing_data.dart';
import 'package:local_sync/features/trust/application/database_service.dart';
import 'package:local_sync/features/trust/application/trust_service.dart';
import 'package:local_sync/features/trust/domain/trusted_peer.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:sqlite3/sqlite3.dart';

part 'trust_providers.g.dart';

/// Provider for the singleton DatabaseService.
@Riverpod(keepAlive: true)
DatabaseService databaseService(Ref ref) {
  final dbService = DatabaseService();
  ref.onDispose(() => dbService.dispose());
  return dbService;
}

/// Asynchronously provides the opened [Database] object.
@Riverpod(keepAlive: true)
Future<Database> database(Ref ref) {
  final dbService = ref.watch(databaseServiceProvider);
  return dbService.db;
}

/// Provider for the singleton TrustService (Repository).
@Riverpod(keepAlive: true)
Future<TrustService> trustService(Ref ref) async {
  final db = await ref.watch(databaseProvider.future);
  return TrustService(db);
}

/// This is the reactive, in-memory "VIP List" for the whole app.
///
/// It's the "single source of truth" for who we trust.
@Riverpod(keepAlive: true)
class TrustList extends _$TrustList {
  @override
  Future<List<TrustedPeer>> build() async {
    final trustService = await ref.watch(trustServiceProvider.future);
    return trustService.getTrustedPeers();
  }

  /// Adds a new peer (from QR scan data) to the database and refreshes the state.
  Future<void> addPeerFromPairingData(PairingData data, String peerName) async {
    final trustService = await ref.read(trustServiceProvider.future);
    final peer = TrustedPeer(
      fingerprint: data.fingerprint,
      name: peerName,
      trustedAt: DateTime.now(),
    );

    await trustService.trustPeer(peer);
    ref.invalidateSelf();
    await future;
  }

  /// Adds a new peer (from a certificate) to the database and refreshes the state.
  Future<void> addPeerFromCertificate(
    String fingerprint,
    String peerName,
  ) async {
    final trustService = await ref.read(trustServiceProvider.future);
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
    final trustService = await ref.read(trustServiceProvider.future);
    await trustService.untrustPeer(fingerprint);
    ref.invalidateSelf();
    await future;
  }
}
