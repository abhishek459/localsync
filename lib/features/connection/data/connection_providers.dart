import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:local_sync/features/connection/application/connection_service.dart';
import 'package:local_sync/features/identity/data/identity_providers.dart';
import 'package:local_sync/features/trust/data/trust_providers.dart';

part 'connection_providers.g.dart';

@Riverpod(keepAlive: true)
int connectionPort(Ref ref) {
  return 45678;
}

/// Manages the lifecycle of the ConnectionService.
/// Asynchronously waits for identity and trust list to be ready.
@Riverpod(keepAlive: true)
Future<ConnectionService> connectionService(Ref ref) async {
  // Await both critical dependencies
  final identity = await ref.watch(deviceIdentityProvider.future);
  final trustList = await ref.watch(trustListProvider.future);

  bool isTrusted(String fingerprint) {
    return trustList.any((peer) => peer.fingerprint == fingerprint);
  }

  // Identity and trustList are guaranteed to be ready here.
  final service = ConnectionService(identity: identity, isTrusted: isTrusted);

  service.startServer();

  ref.onDispose(() {
    service.dispose();
  });

  return service;
}
