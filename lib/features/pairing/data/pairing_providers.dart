import 'dart:io';

import 'package:local_sync/features/connection/data/connection_providers.dart';
import 'package:local_sync/features/identity/data/identity_providers.dart';
import 'package:local_sync/features/pairing/domain/show_my_info_state.dart';
import 'package:local_sync/features/pairing/domain/pairing_data.dart';
import 'package:network_info_plus/network_info_plus.dart';
import 'package:local_auth/local_auth.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'pairing_providers.g.dart';

/// A "bridge" provider used to programmatically request the pairing UI.
@Riverpod(keepAlive: true)
class PairingRequest extends _$PairingRequest {
  @override
  bool build() => false;
  void request() => state = true;
  void consume() => state = false;
}

/// A provider that securely fetches this device's complete pairing information.
@riverpod
Future<PairingData> myPairingData(Ref ref) async {
  // 1. Get Crypto Identity (Rust)
  final identity = await ref.watch(networkIdentityProvider.future);
  if (identity == null) {
    throw Exception("No identity found. Please log in with Master Key.");
  }

  // 2. Get Public ID (Hex String)
  final publicId = await identity.publicId();

  // 3. Get Device Alias (Human Name)
  final identityService = await ref.watch(identityServiceProvider.future);
  final alias = await identityService.getDeviceAlias();

  // 4. Get Port
  final port = await ref.watch(activePortProvider.future);

  // 5. Get IP Address
  String? ip;
  if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
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
        orElse: () => interfaces.firstWhere((i) => i.addresses.isNotEmpty),
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

  if (ip == null) {
    throw Exception(
      'Unable to retrieve local IP address. Ensure you are connected to a network.',
    );
  }

  return PairingData(ip: ip, port: port, deviceId: publicId, alias: alias);
}

/// Notifier for managing the "Show My Info" screen state.
@riverpod
class ShowMyInfo extends _$ShowMyInfo {
  final LocalAuthentication _auth = LocalAuthentication();

  @override
  ShowMyInfoState build() => const ShowMyInfoState();

  Future<void> authenticate() async {
    if (state.status == ShowMyInfoStatus.authenticating) return;
    state = state.copyWith(status: ShowMyInfoStatus.authenticating);

    if (Platform.isLinux || Platform.isWindows || Platform.isMacOS) {
      state = state.copyWith(status: ShowMyInfoStatus.success);
      return;
    }

    try {
      final bool canAuth =
          await _auth.canCheckBiometrics || await _auth.isDeviceSupported();
      if (!canAuth) throw Exception('Local authentication not available.');

      final bool didAuthenticate = await _auth.authenticate(
        localizedReason:
            'Please authenticate to show your connection information',
      );

      if (!ref.mounted) return;
      state = state.copyWith(
        status: didAuthenticate
            ? ShowMyInfoStatus.success
            : ShowMyInfoStatus.unauthenticated,
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
