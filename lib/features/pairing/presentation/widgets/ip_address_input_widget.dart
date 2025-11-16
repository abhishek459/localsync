import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:local_sync/features/shared/presentation/app_sizes.dart';

/// A widget that provides 4 text fields for entering an IP address.
///
/// This widget is a controlled component. It reports its state via [onChanged]
/// and can be initialized or updated via [initialValue].
class IpAddressInputWidget extends StatefulWidget {
  const IpAddressInputWidget({super.key, this.initialValue, this.onChanged});

  /// The initial IP address to display (e.g., "192.168.1.1").
  final String? initialValue;

  /// Called whenever a change results in a new, valid, complete IP address
  /// or an incomplete one. A complete IP will be a string (e.g., "192.168.1.1").
  /// An incomplete or invalid IP will be null.
  final ValueChanged<String?>? onChanged;

  @override
  State<IpAddressInputWidget> createState() => _IpAddressInputWidgetState();
}

class _IpAddressInputWidgetState extends State<IpAddressInputWidget> {
  final _controllers = List.generate(4, (_) => TextEditingController());
  final _focusNodes = List.generate(4, (_) => FocusNode());

  @override
  void initState() {
    super.initState();
    _initializeFields();

    for (int i = 0; i < 4; i++) {
      _controllers[i].addListener(() {
        final text = _controllers[i].text;

        // Auto-advance to next field
        if (text.length == 3 && i < 3) {
          _focusNodes[i + 1].requestFocus();
        }

        // Auto-move focus backward on backspace
        if (text.isEmpty && i > 0) {
          _focusNodes[i - 1].requestFocus();
        }

        // Notify parent of the change
        _notifyParent();
      });

      // Select all text on focus
      _focusNodes[i].addListener(() {
        if (_focusNodes[i].hasFocus) {
          _controllers[i].selectAll();
        }
      });
    }
  }

  /// Sets the initial values of the text fields from widget.initialValue.
  void _initializeFields() {
    if (widget.initialValue == null) {
      // Clear all fields if initialValue is null
      for (final controller in _controllers) {
        controller.clear();
      }
      return;
    }

    final parts = widget.initialValue!.split('.');
    if (parts.length == 4) {
      for (int i = 0; i < 4; i++) {
        // Only update if the text is different to avoid cursor jumps
        if (_controllers[i].text != parts[i]) {
          _controllers[i].text = parts[i];
        }
      }
    }
  }

  /// Gathers text from all controllers and calls widget.onChanged
  void _notifyParent() {
    // Check if all fields are non-empty
    if (_controllers.any((c) => c.text.isEmpty)) {
      widget.onChanged?.call(null);
      return;
    }

    try {
      // Parse all parts to integers to validate range
      final parts = _controllers.map((c) => int.parse(c.text)).toList();

      // All must be valid 0-255 octets
      if (parts.any((p) => p < 0 || p > 255)) {
        widget.onChanged?.call(null);
        return;
      }

      final ip = parts.join('.');
      widget.onChanged?.call(ip);
    } catch (_) {
      // Failed to parse int
      widget.onChanged?.call(null);
    }
  }

  @override
  void didUpdateWidget(covariant IpAddressInputWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    // If the parent passes a new initialValue, update the fields
    if (widget.initialValue != oldWidget.initialValue) {
      _initializeFields();
    }
  }

  @override
  void dispose() {
    for (var c in _controllers) {
      c.dispose();
    }
    for (var f in _focusNodes) {
      f.dispose();
    }
    super.dispose();
  }

  // NO getIpAddress() METHOD - Parent has the value via onChanged.

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        _buildOctetField(0),
        _buildDot(),
        _buildOctetField(1),
        _buildDot(),
        _buildOctetField(2),
        _buildDot(),
        _buildOctetField(3),
      ],
    );
  }

  Widget _buildDot() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSizes.p2),
      child: Text('.', style: Theme.of(context).textTheme.headlineSmall),
    );
  }

  Widget _buildOctetField(int index) {
    return Flexible(
      child: TextField(
        controller: _controllers[index],
        focusNode: _focusNodes[index],
        keyboardType: TextInputType.number,
        textAlign: TextAlign.center,
        style: Theme.of(context).textTheme.titleMedium,
        inputFormatters: [
          FilteringTextInputFormatter.digitsOnly,
          LengthLimitingTextInputFormatter(3),
          IpOctetInputFormatter(), // Custom formatter for 0-255
        ],
        decoration: InputDecoration(
          contentPadding: const EdgeInsets.symmetric(
            vertical: AppSizes.p4,
            horizontal: AppSizes.p2,
          ),
          isDense: true,
        ),
      ),
    );
  }
}

/// A custom [TextInputFormatter] that restricts input to values between 0 and 255.
class IpOctetInputFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    if (newValue.text.isEmpty) {
      return newValue;
    }

    try {
      final int value = int.parse(newValue.text);
      if (value >= 0 && value <= 255) {
        return newValue; // Value is valid
      }
    } catch (_) {
      // Invalid number, just return old value
    }

    return oldValue; // Value is out of range
  }
}

/// Helper extension to select all text in a controller.
extension on TextEditingController {
  void selectAll() {
    selection = TextSelection(baseOffset: 0, extentOffset: text.length);
  }
}
