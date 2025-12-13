import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:local_sync/features/connection/application/connection_service.dart';
import 'package:local_sync/features/identity/data/identity_providers.dart';
import 'package:local_sync/features/transport/message_router.dart';
import 'package:local_sync/features/trust/data/trust_providers.dart';

part 'connection_providers.g.dart';

@Riverpod(keepAlive: true)
Future<int> activePort(Ref ref) async {
  final service = await ref.watch(connectionServiceProvider.future);
  return service?.listeningPort ?? 0;
}

/// Manages the lifecycle of the ConnectionService.
/// Asynchronously waits for identity, trust list, and message router to be ready.
@Riverpod(keepAlive: true)
Future<ConnectionService?> connectionService(Ref ref) async {
  final identity = await ref.watch(networkIdentityProvider.future);
  if (identity == null) return null;

  final messageRouter = await ref.watch(messageRouterProvider.future);

  bool isTrusted(String fingerprint) {
    final list = ref.read(trustListProvider).value ?? [];
    return list.any((peer) => peer.fingerprint == fingerprint);
  }

  // Use the async factory to allow Rust cert generation
  final service = await ConnectionService.create(
    identity: identity,
    isTrusted: isTrusted,
    messageRouter: messageRouter,
  );

  await service.startServer();
  ref.onDispose(() => service.dispose());
  return service;
}
