import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:local_sync/features/connection/application/connection_service.dart';
import 'package:local_sync/features/identity/data/identity_providers.dart';
import 'package:local_sync/features/transport/message_router.dart';
import 'package:local_sync/features/trust/data/trust_providers.dart';

part 'connection_providers.g.dart';

@Riverpod(keepAlive: true)
int connectionPort(Ref ref) {
  return 45678;
}

/// Manages the lifecycle of the ConnectionService.
/// Asynchronously waits for identity, trust list, and message router to be ready.
@Riverpod(keepAlive: true)
Future<ConnectionService> connectionService(Ref ref) async {
  // Await all critical dependencies
  final identity = await ref.watch(deviceIdentityProvider.future);
  final trustList = await ref.watch(trustListProvider.future);
  final messageRouter = await ref.watch(messageRouterProvider.future);

  bool isTrusted(String fingerprint) {
    return trustList.any((peer) => peer.fingerprint == fingerprint);
  }

  // Identity, trustList, and router are guaranteed to be ready here.
  final service = ConnectionService(
    identity: identity,
    isTrusted: isTrusted,
    messageRouter: messageRouter,
  );

  service.startServer();

  ref.onDispose(() {
    service.dispose();
  });

  return service;
}
