import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:local_sync/features/connection/data/connection_providers.dart';
import 'package:local_sync/features/pairing/domain/pairing_data.dart';
import 'package:local_sync/features/pairing/presentation/widgets/ip_address_input_widget.dart';
import 'package:local_sync/features/pairing/presentation/widgets/show_my_info_widget.dart';
import 'package:local_sync/features/shared/application/app_notification_provider.dart';
import 'package:local_sync/features/shared/presentation/app_sizes.dart';
import 'package:local_sync/features/trust/data/trust_providers.dart';

class ManualPairingTab extends ConsumerStatefulWidget {
  const ManualPairingTab({super.key});

  @override
  ConsumerState<ManualPairingTab> createState() => _ManualPairingTabState();
}

class _ManualPairingTabState extends ConsumerState<ManualPairingTab> {
  final _formKey = GlobalKey<FormState>();
  String? _ipAddress;
  final _portController = TextEditingController();
  final _fingerprintController = TextEditingController();
  final _aliasController = TextEditingController();

  @override
  void initState() {
    super.initState();
    final asyncPort = ref.read(activePortProvider);
    if (asyncPort.hasValue) {
      _portController.text = asyncPort.value.toString();
    }
  }

  @override
  void dispose() {
    _portController.dispose();
    _fingerprintController.dispose();
    _aliasController.dispose();
    super.dispose();
  }

  Future<void> _onTrustAndConnect() async {
    final isValid = _formKey.currentState?.validate() ?? false;
    if (!isValid || _ipAddress == null) {
      NotificationReporter.reportMessage(
        'Please correct the errors in the form.',
      );
      return;
    }

    try {
      final pairingData = PairingData(
        ip: _ipAddress!,
        port: int.parse(_portController.text),
        deviceId: _fingerprintController.text,
        alias: _aliasController.text,
      );

      await ref
          .read(trustListProvider.notifier)
          .addPeerFromPairingData(pairingData, pairingData.alias);

      if (!mounted) return;
      NotificationReporter.reportSuccess('${pairingData.alias} trusted!');
      Navigator.of(context).popUntil((route) => route.isFirst);
    } catch (e) {
      if (!mounted) return;
      NotificationReporter.reportError(
        e,
        userFriendlyMessage: 'Failed to add peer.',
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool isDesktop = !Platform.isAndroid && !Platform.isIOS;

    return Form(
      key: _formKey,
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(AppSizes.p4),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (!isDesktop) const ShowMyInfoWidget(),
            if (!isDesktop) const SizedBox(height: AppSizes.p4),
            if (!isDesktop) const Divider(),
            if (!isDesktop) const SizedBox(height: AppSizes.p4),
            Text(
              'Connect to Peer',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: AppSizes.p2),
            const Text('Enter the details shown on the other device.'),
            const SizedBox(height: AppSizes.p4),

            // 1. Device Name Input (NEW)
            TextFormField(
              controller: _aliasController,
              decoration: const InputDecoration(
                labelText: 'Device Name (Alias)',
                hintText: 'e.g. Dad\'s Laptop',
                prefixIcon: Icon(Icons.badge_outlined),
              ),
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Please give this device a name';
                }
                return null;
              },
            ),
            const SizedBox(height: AppSizes.p4),
            IpAddressInputWidget(
              onChanged: (String? ip) {
                setState(() {
                  _ipAddress = ip;
                });
              },
            ),
            const SizedBox(height: AppSizes.p4),
            TextFormField(
              controller: _portController,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              decoration: const InputDecoration(
                labelText: 'Port',
                prefixIcon: Icon(Icons.numbers),
              ),
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Port is required';
                }
                final port = int.tryParse(value);
                if (port == null || port <= 0 || port > 65535) {
                  return 'Invalid port (1-65535)';
                }
                return null;
              },
            ),
            const SizedBox(height: AppSizes.p4),
            TextFormField(
              controller: _fingerprintController,
              decoration: const InputDecoration(
                labelText: 'Device Fingerprint',
                hintText: 'SHA-256 string',
                prefixIcon: Icon(Icons.fingerprint),
              ),
              style: Theme.of(context).textTheme.bodySmall,
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Fingerprint is required';
                }
                if (value.length < 10) {
                  return 'Invalid fingerprint';
                }
                return null;
              },
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: _onTrustAndConnect,
              style: FilledButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: AppSizes.p4),
              ),
              icon: const Icon(Icons.verified_user),
              label: const Text('Trust & Add Device'),
            ),
          ],
        ),
      ),
    );
  }
}
