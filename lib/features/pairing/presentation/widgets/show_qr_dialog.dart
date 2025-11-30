import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:local_sync/features/pairing/domain/pairing_data.dart';
import 'package:pretty_qr_code/pretty_qr_code.dart';

class ShowMyQrDialog extends StatelessWidget {
  final PairingData pairingData;

  const ShowMyQrDialog({super.key, required this.pairingData});

  @override
  Widget build(BuildContext context) {
    // Serialize the data to JSON
    final qrData = jsonEncode(pairingData.toJson());

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          width: 250,
          height: 250,
          child: PrettyQrView.data(
            data: qrData,
            decoration: PrettyQrDecoration(
              shape: PrettyQrSquaresSymbol(
                color: Theme.of(context).colorScheme.onSurface,
              ),
            ),
          ),
        ),
      ],
    );
  }
}
