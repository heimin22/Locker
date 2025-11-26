import 'package:flutter/material.dart';
import '../themes/app_colors.dart';
import '../services/auth_service.dart';
import 'gallery_vault_screen.dart';

/// Biometric setup screen
class BiometricSetupScreen extends StatefulWidget {
  const BiometricSetupScreen({super.key});

  @override
  State<BiometricSetupScreen> createState() => _BiometricSetupScreenState();
}

class _BiometricSetupScreenState extends State<BiometricSetupScreen> {
  final AuthService _authService = AuthService();
  bool _isLoading = false;
  String? _errorMessage;
  String _biometricType = 'Fingerprint';

  @override
  void initState() {
    super.initState();
    _loadBiometricType();
  }

  Future<void> _loadBiometricType() async {
    final biometrics = await _authService.getAvailableBiometrics();
    setState(() {
      _biometricType = _authService.getBiometricDisplayName(biometrics);
    });
  }

  Future<void> _handleSetupBiometric() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    final success = await _authService.setupBiometricAuthentication();

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
        _errorMessage =
            'Failed to set up biometric authentication. Please try again.';
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
          onPressed: _isLoading ? null : () => Navigator.pop(context),
        ),
        title: Text(
          'Biometric Setup',
          style: TextStyle(
            fontFamily: 'ProductSans',
            color: AppColors.lightTextPrimary,
          ),
        ),
        backgroundColor: AppColors.lightBackground,
        elevation: 0,
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 32),

              // Icon
              Center(
                child: Container(
                  width: 120,
                  height: 120,
                  decoration: BoxDecoration(
                    color: AppColors.accentLight.withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.fingerprint,
                    size: 64,
                    color: AppColors.accent,
                  ),
                ),
              ),

              const SizedBox(height: 32),

              // Title
              Text(
                'Set up $_biometricType',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w600,
                  color: AppColors.lightTextPrimary,
                  fontFamily: 'ProductSans',
                ),
                textAlign: TextAlign.center,
              ),

              const SizedBox(height: 16),

              // Description
              Text(
                'Use your device\'s $_biometricType to quickly and securely unlock your media vault.',
                style: TextStyle(
                  fontSize: 16,
                  color: AppColors.lightTextSecondary,
                  fontFamily: 'ProductSans',
                ),
                textAlign: TextAlign.center,
              ),

              const SizedBox(height: 32),

              // Error Message
              if (_errorMessage != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.error.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      _errorMessage!,
                      style: TextStyle(
                        color: AppColors.error,
                        fontSize: 14,
                        fontFamily: 'ProductSans',
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),

              const Spacer(),

              // Setup Button
              ElevatedButton(
                onPressed: _isLoading ? null : _handleSetupBiometric,
                child: _isLoading
                    ? SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor:
                              AlwaysStoppedAnimation<Color>(Colors.white),
                        ),
                      )
                    : Padding(
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        child: Text(
                          'Set up $_biometricType',
                          style: TextStyle(
                            fontSize: 16,
                            fontFamily: 'ProductSans',
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
              ),

              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }
}
