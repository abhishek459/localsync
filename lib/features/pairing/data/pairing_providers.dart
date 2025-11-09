import 'dart:io';

import 'package:local_sync/features/connection/data/connection_providers.dart';
import 'package:local_sync/features/identity/data/identity_providers.dart';
import 'package:local_sync/features/pairing/domain/show_my_info_state.dart';
import 'package:local_sync/features/pairing/domain/pairing_data.dart';
import 'package:network_info_plus/network_info_plus.dart';
import 'package:local_auth/local_auth.dart';
import 'package:flutter/services.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'pairing_providers.g.dart';

/// A "bridge" provider used to programmatically request the pairing UI.
@Riverpod(keepAlive: true)
class PairingRequest extends _$PairingRequest {
  @override
  bool build() {
    return false;
  }

  void request() {
    state = true;
  }

  void consume() {
    state = false;
  }
}

/// A provider that securely fetches this device's complete pairing information.
@riverpod
Future<PairingData> myPairingData(Ref ref) async {
  final identityFuture = ref.watch(deviceIdentityProvider.future);
  final port = ref.watch(connectionPortProvider);
  final ipFuture = NetworkInfo().getWifiIP();

  final identity = await identityFuture;
  final ip = await ipFuture;

  if (ip == null) {
    throw Exception(
      'Unable to retrieve Wi-Fi IP address. '
      'Please ensure you are connected to a Wi-Fi network.',
    );
  }

  return PairingData(ip: ip, port: port, fingerprint: identity.fingerprint);
}

/// Notifier for managing the "Show My Info" screen state.
@riverpod
class ShowMyInfo extends _$ShowMyInfo {
  final LocalAuthentication _auth = LocalAuthentication();

  @override
  ShowMyInfoState build() {
    // This correctly returns the default state:
    // ShowMyInfoState(status: ShowMyInfoStatus.unauthenticated)
    return const ShowMyInfoState();
  }

  Future<void> authenticate() async {
    if (state.status == ShowMyInfoStatus.authenticating) {
      return;
    }

    state = state.copyWith(status: ShowMyInfoStatus.authenticating);

    if (Platform.isLinux || Platform.isWindows) {
      state = state.copyWith(status: ShowMyInfoStatus.success);
      return;
    }

    try {
      final bool canAuth =
          await _auth.canCheckBiometrics || await _auth.isDeviceSupported();
      if (!canAuth) {
        throw Exception(
          'Local authentication is not available on this device.',
        );
      }

      final bool didAuthenticate = await _auth.authenticate(
        localizedReason:
            'Please authenticate to show your connection information',
      );

      if (!ref.mounted) return;

      if (didAuthenticate) {
        state = state.copyWith(status: ShowMyInfoStatus.success);
      } else {
        state = state.copyWith(status: ShowMyInfoStatus.unauthenticated);
      }
    } on PlatformException catch (e) {
      if (!ref.mounted) return;
      state = state.copyWith(
        status: ShowMyInfoStatus.error,
        errorMessage: e.message ?? 'Authentication failed',
      );
    } catch (e) {
      if (!ref.mounted) return;
      state = state.copyWith(
        status: ShowMyInfoStatus.error,
        errorMessage: e.toString(),
      );
    }
  }
}
