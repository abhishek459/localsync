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

  // Handle Desktop vs Mobile IP fetching
  String? ip;

  if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
    // On Desktop, use the robust dart:io NetworkInterface to find an IP.
    // This works for Ethernet AND Wi-Fi.
    try {
      final interfaces = await NetworkInterface.list(
        type: InternetAddressType.IPv4,
        includeLoopback: false,
      );

      // Filter out common virtual adapters and link-local addresses
      final validInterface = interfaces.firstWhere(
        (interface) {
          // Filter out empty interfaces
          if (interface.addresses.isEmpty) return false;

          final name = interface.name.toLowerCase();

          // Filter out common virtual environment names
          bool isVirtual =
              name.contains('docker') ||
              name.contains('vethernet') ||
              name.contains('wsl') ||
              name.contains('vmware') ||
              name.contains('virtualbox');

          if (isVirtual) return false;

          // Check the actual IP address to ensure it's not link-local (169.254.x.x)
          // Link-local means the interface is active but has no DHCP assignment.
          final address = interface.addresses.first.address;
          if (address.startsWith('169.254')) return false;

          return true;
        },
        // Fallback: If we filtered everything out, just take the first non-empty one
        orElse: () => interfaces.firstWhere(
          (i) => i.addresses.isNotEmpty,
          orElse: () => throw Exception('No network interfaces found'),
        ),
      );

      ip = validInterface.addresses.first.address;
    } catch (e) {
      ip = null;
    }
  } else {
    // On Mobile (Android/iOS), using network_info_plus as it
    // handles specific mobile permissions and Wi-Fi state better.
    ip = await NetworkInfo().getWifiIP();
  }

  final identity = await identityFuture;

  if (ip == null) {
    throw Exception(
      'Unable to retrieve local IP address. '
      'Please ensure you are connected to a network.',
    );
  }

  return PairingData(ip: ip, port: port, fingerprint: identity.deviceId);
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

    if (Platform.isLinux || Platform.isWindows || Platform.isMacOS) {
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
