import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:local_sync/features/pairing/domain/pairing_data.dart';
import 'package:local_sync/features/pairing/presentation/widgets/scanner_overlay.dart';
import 'package:local_sync/features/trust/data/trust_providers.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

/// This tab contains the `MobileScanner` widget and handles the
/// "scan to pair" flow, which is an *explicit* trust action.
class QrScannerTab extends ConsumerStatefulWidget {
  const QrScannerTab({super.key});

  @override
  ConsumerState<QrScannerTab> createState() => _QrScannerTabState();
}

class _QrScannerTabState extends ConsumerState<QrScannerTab> {
  final MobileScannerController _controller = MobileScannerController(
    detectionSpeed: DetectionSpeed.noDuplicates,
  );
  bool _isProcessing = false; // Prevents double-scans

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _onDetect(BarcodeCapture capture) async {
    // Prevent multiple dialogs
    if (_isProcessing) return;
    setState(() => _isProcessing = true);

    final barcode = capture.barcodes.first;

    if (barcode.rawValue == null) {
      _showError('Scanned QR code is empty.');
      // Allow scanning again
      setState(() => _isProcessing = false);
      return;
    }

    try {
      final pairingData = PairingData.fromJson(barcode.rawValue!);

      // Show the TOFU confirmation dialog
      final bool? didTrust = await showDialog<bool>(
        context: context,
        barrierDismissible: false,
        builder: (context) => AlertDialog(
          title: const Text('Trust This Device?'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'A peer was found. Please verify its fingerprint matches the one shown on the other device.',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const SizedBox(height: 16),
              Text(
                'PEER FINGERPRINT:',
                style: Theme.of(context).textTheme.labelSmall,
              ),
              SelectableText(
                pairingData.fingerprint,
                style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Trust'),
            ),
          ],
        ),
      );

      // If user pressed "Trust"
      if (didTrust == true) {
        // We use a placeholder name for now.
        // A better implementation would be to get the name from the
        // certificate *after* connecting, but this is secure.
        await ref
            .read(trustListProvider.notifier)
            .addPeerFromPairingData(pairingData, 'Scanned Peer');

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Peer trusted! You can now connect.'),
              backgroundColor: Colors.green,
            ),
          );
          // Pop the whole pairing screen
          Navigator.of(context).popUntil((route) => route.isFirst);
        }
      }
    } catch (e) {
      _showError('Invalid QR code format. $e');
    }

    // Finished processing, allow scanning again
    if (mounted) {
      setState(() => _isProcessing = false);
    }
  }

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.red),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        MobileScanner(controller: _controller, onDetect: _onDetect),
        // The "Scan Window" overlay
        const Center(child: ScannerOverlay(overlayColour: Colors.black54)),
      ],
    );
  }
}
