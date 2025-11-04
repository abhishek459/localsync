import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:local_sync/features/connection/data/connection_providers.dart';
import 'package:local_sync/features/pairing/domain/pairing_data.dart';
import 'package:local_sync/features/pairing/presentation/widgets/ip_address_input_widget.dart';
import 'package:local_sync/features/pairing/presentation/widgets/show_my_info_widget.dart';
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

  @override
  void initState() {
    super.initState();
    _portController.text = ref.read(connectionPortProvider).toString();
  }

  @override
  void dispose() {
    _portController.dispose();
    _fingerprintController.dispose();
    super.dispose();
  }

  Future<void> _onTrustAndConnect() async {
    final isValid = _formKey.currentState?.validate() ?? false;
    if (!isValid || _ipAddress == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please correct the errors in the form.'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    try {
      final pairingData = PairingData(
        ip: _ipAddress!,
        port: int.parse(_portController.text),
        fingerprint: _fingerprintController.text,
      );

      await ref
          .read(trustListProvider.notifier)
          .addPeerFromPairingData(pairingData, 'Manually Added Peer');

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Peer trusted! You can now connect.'),
          backgroundColor: Colors.green,
        ),
      );
      Navigator.of(context).popUntil((route) => route.isFirst);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to add peer: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Form(
      key: _formKey,
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const ShowMyInfoWidget(),
            const SizedBox(height: 16),
            const Divider(),
            const SizedBox(height: 16),
            Text(
              'Connect to Peer',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 8),
            const Text(
              'Enter the IP, Port, and Fingerprint shown on your other device.',
            ),
            const SizedBox(height: 16),
            IpAddressInputWidget(
              onChanged: (String? ip) {
                setState(() {
                  _ipAddress = ip;
                });
              },
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _portController,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              decoration: const InputDecoration(
                labelText: 'Port',
                border: OutlineInputBorder(),
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
            const SizedBox(height: 16),
            TextFormField(
              controller: _fingerprintController,
              decoration: const InputDecoration(
                labelText: 'Device Fingerprint',
                border: OutlineInputBorder(),
              ),
              style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
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
            FilledButton(
              onPressed: _onTrustAndConnect,
              style: FilledButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
              child: const Text('Trust & Add Device'),
            ),
          ],
        ),
      ),
    );
  }
}
