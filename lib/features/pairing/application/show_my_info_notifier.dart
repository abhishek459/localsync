import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:local_auth/local_auth.dart';
import 'package:flutter/services.dart';

enum ShowMyInfoStatus { unauthenticated, authenticating, success, error }

@immutable
class ShowMyInfoState {
  const ShowMyInfoState({
    this.status = ShowMyInfoStatus.unauthenticated,
    this.errorMessage,
  });

  final ShowMyInfoStatus status;
  final String? errorMessage;

  ShowMyInfoState copyWith({ShowMyInfoStatus? status, String? errorMessage}) {
    return ShowMyInfoState(
      status: status ?? this.status,
      errorMessage: errorMessage ?? this.errorMessage,
    );
  }
}

class ShowMyInfoNotifier extends Notifier<ShowMyInfoState> {
  final LocalAuthentication _auth = LocalAuthentication();

  @override
  ShowMyInfoState build() {
    return const ShowMyInfoState();
  }

  Future<void> authenticate() async {
    if (state.status == ShowMyInfoStatus.authenticating) {
      return;
    }

    state = state.copyWith(status: ShowMyInfoStatus.authenticating);

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

      // Check if the notifier is still mounted after the auth await
      if (!ref.mounted) return;

      if (didAuthenticate) {
        // We no longer fetch data here. We just report success.
        state = state.copyWith(status: ShowMyInfoStatus.success);
      } else {
        // User cancelled auth, return to initial state
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
