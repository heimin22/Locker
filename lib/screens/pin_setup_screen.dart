import 'package:flutter/material.dart';
import '../themes/app_colors.dart';
import '../widgets/pin_input_widget.dart';
import '../services/auth_service.dart';
import 'gallery_vault_screen.dart';

/// PIN setup screen with confirmation
class PinSetupScreen extends StatefulWidget {
  const PinSetupScreen({super.key});

  @override
  State<PinSetupScreen> createState() => _PinSetupScreenState();
}

class _PinSetupScreenState extends State<PinSetupScreen> {
  final AuthService _authService = AuthService();
  String? _firstPin;
  bool _isConfirmation = false;
  String? _errorMessage;
  bool _isLoading = false;

  void _handlePinComplete(String pin) async {
    if (!_isConfirmation) {
      // First PIN entry
      setState(() {
        _firstPin = pin;
        _isConfirmation = true;
        _errorMessage = null;
      });
    } else {
      // Confirmation PIN entry
      if (pin == _firstPin) {
        // PINs match, save and navigate
        setState(() {
          _isLoading = true;
          _errorMessage = null;
        });

        final success = await _authService.createPIN(pin);

        if (success && mounted) {
          Navigator.of(context).pushAndRemoveUntil(
            MaterialPageRoute(
              builder: (context) => const GalleryVaultScreen(),
            ),
            (route) => false,
          );
        } else if (mounted) {
          setState(() {
            _isLoading = false;
            _errorMessage = 'Failed to save PIN. Please try again.';
            _isConfirmation = false;
            _firstPin = null;
          });
        }
      } else {
        // PINs don't match
        setState(() {
          _errorMessage = 'PINs do not match. Please try again.';
          _isConfirmation = false;
          _firstPin = null;
        });
      }
    }
  }

  void _handlePinChanged() {
    if (_errorMessage != null) {
      setState(() {
        _errorMessage = null;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.lightBackground,
      appBar: AppBar(
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: AppColors.lightTextPrimary),
          onPressed: _isLoading
              ? null
              : () {
                  if (_isConfirmation) {
                    // Go back to first PIN entry
                    setState(() {
                      _isConfirmation = false;
                      _firstPin = null;
                      _errorMessage = null;
                    });
                  } else {
                    Navigator.pop(context);
                  }
                },
        ),
        title: Text(
          _isConfirmation ? 'Confirm PIN' : 'Create PIN',
          style: TextStyle(
            fontFamily: 'ProductSans',
            color: AppColors.lightTextPrimary,
          ),
        ),
        backgroundColor: AppColors.lightBackground,
        elevation: 0,
      ),
      body: _isLoading
          ? Center(
              child: CircularProgressIndicator(
                color: AppColors.accent,
              ),
            )
          : SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  children: [
                    const SizedBox(height: 32),

                    // Instruction Text
                    Text(
                      _isConfirmation
                          ? 'Enter your PIN again to confirm'
                          : 'Enter a 6-digit PIN',
                      style: TextStyle(
                        fontSize: 18,
                        color: AppColors.lightTextSecondary,
                        fontFamily: 'ProductSans',
                      ),
                      textAlign: TextAlign.center,
                    ),

                    const SizedBox(height: 64),

                    // PIN Input Widget
                    PinInputWidget(
                      onPinComplete: _handlePinComplete,
                      onPinChanged: _handlePinChanged,
                      errorMessage: _errorMessage,
                    ),

                    const Spacer(),
                  ],
                ),
              ),
            ),
    );
  }
}
