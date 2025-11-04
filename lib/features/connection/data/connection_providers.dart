import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:local_sync/features/connection/application/connection_service.dart';
import 'package:local_sync/features/identity/data/identity_providers.dart';
import 'package:local_sync/features/identity/domain/device_identity.dart';
import 'package:local_sync/features/trust/data/trust_providers.dart';

final connectionServiceProvider = Provider<ConnectionService>((ref) {
  final identityAsync = ref.watch(deviceIdentityProvider);
  final identity = identityAsync.value;
  final trustList = ref.watch(trustListProvider).value ?? [];

  bool isTrusted(String fingerprint) {
    return trustList.any((peer) => peer.fingerprint == fingerprint);
  }

  if (identity == null ||
      identity.fingerprint.isEmpty ||
      identity.certificate == null ||
      identity.privateKeyPem == null) {
    return ConnectionService(
      identity: DeviceIdentity.empty,
      isTrusted: (fp) => false,
    );
  }

  final service = ConnectionService(identity: identity, isTrusted: isTrusted);

  service.startServer();

  ref.onDispose(() {
    service.dispose();
  });

  return service;
});

final connectionPortProvider = Provider<int>((ref) {
  return 45678;
});
