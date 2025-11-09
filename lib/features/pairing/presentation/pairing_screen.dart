import 'dart:io';

import 'package:flutter/material.dart';
import 'package:local_sync/features/pairing/presentation/tabs/manual_pairing_tab.dart';
import 'package:local_sync/features/pairing/presentation/tabs/qr_scanner_tab.dart';

/// This is the main "Add Device" screen.
/// It acts as a launchpad for our two manual pairing flows.
class PairingScreen extends StatelessWidget {
  const PairingScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final bool isMobile = (Platform.isAndroid || Platform.isIOS);

    if (isMobile) {
      return DefaultTabController(
        length: 2,
        child: Scaffold(
          appBar: AppBar(
            title: const Text('Add a New Device'),
            bottom: const TabBar(
              tabs: [
                Tab(icon: Icon(Icons.qr_code_scanner), text: 'Scan to Pair'),
                Tab(icon: Icon(Icons.abc), text: 'Manual Connection'),
              ],
            ),
            actions: [
              IconButton(
                icon: const Icon(Icons.help_outline),
                tooltip: 'Why do I need to do this?',
                onPressed: () {
                  showDialog(
                    context: context,
                    builder: (context) => AlertDialog(
                      title: const Text('Manual Connection'),
                      content: const Text(
                        'Automatic discovery (mDNS) can be blocked by some networks (like Guest Wi-Fi, university networks, or mobile hotspots).\n\n'
                        'Use "Scan to Pair" (recommended) or "Manual Connection" to reliably connect to your other device.',
                      ),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.of(context).pop(),
                          child: const Text('OK'),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ],
          ),
          body: TabBarView(
            // We disable swiping to prevent issues with the scanner
            physics: NeverScrollableScrollPhysics(),
            children: [QrScannerTab(), ManualPairingTab()],
          ),
        ),
      );
    } else {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Add a New Device'),

          actions: [
            IconButton(
              icon: const Icon(Icons.help_outline),
              tooltip: 'Why do I need to do this?',
              onPressed: () {
                showDialog(
                  context: context,
                  builder: (context) => AlertDialog(
                    title: const Text('Manual Connection'),
                    content: const Text(
                      'Automatic discovery (mDNS) can be blocked by some networks (like Guest Wi-Fi, university networks, or mobile hotspots).\n\n'
                      'Use "Scan to Pair" (recommended) or "Manual Connection" to reliably connect to your other device.',
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.of(context).pop(),
                        child: const Text('OK'),
                      ),
                    ],
                  ),
                );
              },
            ),
          ],
        ),
        body: ManualPairingTab(),
      );
    }
  }
}
