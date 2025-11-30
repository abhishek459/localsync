// lib/features/pairing/presentation/widgets/pairing_info_display.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:local_sync/features/pairing/domain/pairing_data.dart';
import 'package:local_sync/features/pairing/presentation/widgets/show_qr_dialog.dart';
import 'package:local_sync/features/shared/application/app_notification_provider.dart';
import 'package:local_sync/features/shared/presentation/app_sizes.dart';

class DisplayPairingInfo extends StatelessWidget {
  final PairingData pairingData;

  const DisplayPairingInfo({super.key, required this.pairingData});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Your Connection Info',
          style: Theme.of(context).textTheme.headlineSmall,
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: AppSizes.p4),
        ShowMyQrDialog(pairingData: pairingData),
        const SizedBox(height: AppSizes.p4),
        _buildInfoRow(context, 'Wi-Fi IP Address:', pairingData.ip),
        const SizedBox(height: AppSizes.p4),
        _buildInfoRow(context, 'Port:', pairingData.port.toString()),
        const SizedBox(height: AppSizes.p4),
        _buildInfoRow(context, 'Device Fingerprint:', pairingData.deviceId),
      ],
    );
  }

  Widget _buildInfoRow(BuildContext context, String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: Theme.of(context).textTheme.labelLarge),
        Row(
          children: [
            Expanded(child: SelectableText(value)),
            IconButton(
              icon: const Icon(Icons.copy, size: 16),
              onPressed: () {
                Clipboard.setData(ClipboardData(text: value));
                NotificationReporter.reportInfo('Copied to clipboard');
              },
            ),
          ],
        ),
      ],
    );
  }
}
