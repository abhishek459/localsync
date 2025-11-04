import 'package:flutter/material.dart';

/// A simple overlay with a "scan window" to guide the user.
class ScannerOverlay extends StatelessWidget {
  final Color overlayColour;
  const ScannerOverlay({super.key, this.overlayColour = Colors.black54});

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final scanWindowSize = size.width * 0.7;

    return ColorFiltered(
      colorFilter: ColorFilter.mode(overlayColour, BlendMode.srcOut),
      child: Stack(
        children: [
          Container(decoration: const BoxDecoration(color: Colors.transparent)),
          Align(
            alignment: Alignment.center,
            child: Container(
              height: scanWindowSize,
              width: scanWindowSize,
              decoration: BoxDecoration(
                color: Colors.black,
                borderRadius: BorderRadius.circular(16),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
