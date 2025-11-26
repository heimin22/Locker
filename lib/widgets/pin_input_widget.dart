import 'package:flutter/material.dart';
import '../themes/app_colors.dart';

/// Custom PIN input widget with numeric keypad
class PinInputWidget extends StatefulWidget {
  final Function(String) onPinComplete;
  final VoidCallback? onPinChanged;
  final String? errorMessage;

  const PinInputWidget({
    super.key,
    required this.onPinComplete,
    this.onPinChanged,
    this.errorMessage,
  });

  @override
  State<PinInputWidget> createState() => _PinInputWidgetState();
}

class _PinInputWidgetState extends State<PinInputWidget> {
  String _pin = '';
  final int _pinLength = 6;

  void _addDigit(String digit) {
    if (_pin.length < _pinLength) {
      setState(() {
        _pin += digit;
      });
      widget.onPinChanged?.call();

      if (_pin.length == _pinLength) {
        widget.onPinComplete(_pin);
      }
    }
  }

  void _removeDigit() {
    if (_pin.isNotEmpty) {
      setState(() {
        _pin = _pin.substring(0, _pin.length - 1);
      });
      widget.onPinChanged?.call();
    }
  }

  void _clearPin() {
    setState(() {
      _pin = '';
    });
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // PIN Display
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(_pinLength, (index) {
            return Container(
              margin: const EdgeInsets.symmetric(horizontal: 8),
              width: 16,
              height: 16,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: index < _pin.length
                    ? AppColors.accent
                    : AppColors.lightBorder,
                border: Border.all(
                  color: index < _pin.length
                      ? AppColors.accent
                      : AppColors.lightBorder,
                  width: 2,
                ),
              ),
            );
          }),
        ),

        const SizedBox(height: 16),

        // Error Message
        if (widget.errorMessage != null)
          Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: Text(
              widget.errorMessage!,
              style: TextStyle(
                color: AppColors.error,
                fontSize: 14,
                fontFamily: 'ProductSans',
              ),
            ),
          ),

        const SizedBox(height: 32),

        // Numeric Keypad
        SizedBox(
          width: 280,
          child: Column(
            children: [
              _buildKeypadRow(['1', '2', '3']),
              const SizedBox(height: 16),
              _buildKeypadRow(['4', '5', '6']),
              const SizedBox(height: 16),
              _buildKeypadRow(['7', '8', '9']),
              const SizedBox(height: 16),
              _buildKeypadRow(['', '0', 'delete']),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildKeypadRow(List<String> keys) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: keys.map((key) {
        if (key.isEmpty) {
          return const SizedBox(width: 70, height: 70);
        }

        if (key == 'delete') {
          return InkWell(
            onTap: _removeDigit,
            borderRadius: BorderRadius.circular(35),
            child: Container(
              width: 70,
              height: 70,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.lightBackgroundSecondary,
              ),
              child: Icon(
                Icons.backspace_outlined,
                color: AppColors.lightTextPrimary,
                size: 24,
              ),
            ),
          );
        }

        return InkWell(
          onTap: () => _addDigit(key),
          borderRadius: BorderRadius.circular(35),
          child: Container(
            width: 70,
            height: 70,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AppColors.lightBackgroundSecondary,
            ),
            child: Center(
              child: Text(
                key,
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w500,
                  color: AppColors.lightTextPrimary,
                  fontFamily: 'ProductSans',
                ),
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  // Method to expose clear function
  void clearPin() {
    _clearPin();
  }
}
