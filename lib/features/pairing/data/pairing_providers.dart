import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:local_sync/features/connection/data/connection_providers.dart';
import 'package:local_sync/features/identity/data/identity_providers.dart';
import 'package:local_sync/features/pairing/application/show_my_info_notifier.dart';
import 'package:local_sync/features/pairing/domain/pairing_data.dart';
import 'package:network_info_plus/network_info_plus.dart';

/// Notifier for managing the pairing request state.
class PairingRequestNotifier extends Notifier<bool> {
  @override
  bool build() {
    return false;
  }

  /// Sets the state to true to request the pairing UI.
  void request() {
    state = true;
  }

  /// Sets the state back to false, "consuming" the request.
  /// This is called by the listener in main.dart.
  void consume() {
    state = false;
  }
}

/// A "bridge" provider used to programmatically request the pairing UI.
final pairingRequestProvider = NotifierProvider<PairingRequestNotifier, bool>(
  PairingRequestNotifier.new,
);

/// A provider that securely fetches this device's complete pairing information.
///
/// It combines the device fingerprint (from [deviceIdentityProvider]) and the
/// local network IP (from [NetworkInfo]) to produce a [PairingData] object.
final myPairingDataProvider = FutureProvider.autoDispose<PairingData>((
  ref,
) async {
  // Fetch the two pieces of data in parallel.
  final identityFuture = ref.watch(deviceIdentityProvider.future);
  final port = ref.watch(connectionPortProvider);
  final ipFuture = NetworkInfo().getWifiIP();

  final identity = await identityFuture;
  final ip = await ipFuture;

  if (!ref.mounted) {
    throw Exception('Operation cancelled.');
  }

  if (ip == null) {
    throw Exception(
      'Unable to retrieve Wi-Fi IP address. '
      'Please ensure you are connected to a Wi-Fi network.',
    );
  }

  return PairingData(ip: ip, port: port, fingerprint: identity.fingerprint);
});

final showMyInfoProvider =
    NotifierProvider.autoDispose<ShowMyInfoNotifier, ShowMyInfoState>(
      ShowMyInfoNotifier.new,
    );
