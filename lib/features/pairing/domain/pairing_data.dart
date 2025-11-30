import 'package:freezed_annotation/freezed_annotation.dart';

part 'pairing_data.freezed.dart';
part 'pairing_data.g.dart';

@freezed
abstract class PairingData with _$PairingData {
  const factory PairingData({
    /// The unique SHA-256 Fingerprint from the Identity Certificate.
    required String deviceId,

    /// The human-readable name (e.g. "Abhishek's Pixel").
    required String alias,

    /// The local IP address (e.g., 192.168.1.5).
    required String ip,

    /// The port the server is listening on (default: 45678).
    required int port,
  }) = _PairingData;

  factory PairingData.fromJson(Map<String, dynamic> json) =>
      _$PairingDataFromJson(json);
}
