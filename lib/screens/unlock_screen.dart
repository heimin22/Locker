import 'package:flutter/material.dart';
import '../themes/app_colors.dart';
import '../services/auth_service.dart';
import '../widgets/pin_input_widget.dart';
import 'gallery_vault_screen.dart';

/// Unlock screen for returning users
class UnlockScreen extends StatefulWidget {
  const UnlockScreen({super.key});

  @override
  State<UnlockScreen> createState() => _UnlockScreenState();
}

class _UnlockScreenState extends State<UnlockScreen> {
  final AuthService _authService = AuthService();
  String? _authMethod;
  String? _errorMessage;
  bool _isLoading = true;
  bool _obscurePassword = true;
  final TextEditingController _passwordController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadAuthMethod();
  }

  @override
  void dispose() {
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _loadAuthMethod() async {
    final method = await _authService.getAuthMethod();
    setState(() {
      _authMethod = method;
      _isLoading = false;
    });

    // Auto-trigger biometric if that's the method
    if (method == 'biometric') {
      _handleBiometricAuth();
    }
  }

  Future<void> _handlePinComplete(String pin) async {
    final isValid = await _authService.verifyPIN(pin);

    if (isValid && mounted) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (context) => const GalleryVaultScreen(),
        ),
      );
    } else if (mounted) {
      setState(() {
        _errorMessage = 'Incorrect PIN. Please try again.';
      });
    }
  }

  void _handlePinChanged() {
    if (_errorMessage != null) {
      setState(() {
        _errorMessage = null;
      });
    }
  }

  Future<void> _handlePasswordAuth() async {
    final password = _passwordController.text;

    if (password.isEmpty) {
      setState(() {
        _errorMessage = 'Please enter your password';
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    final isValid = await _authService.verifyPassword(password);

    if (isValid && mounted) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (context) => const GalleryVaultScreen(),
        ),
      );
    } else if (mounted) {
      setState(() {
        _isLoading = false;
        _errorMessage = 'Incorrect password. Please try again.';
        _passwordController.clear();
      });
    }
  }

  Future<void> _handleBiometricAuth() async {
    final isAuthenticated = await _authService.authenticateWithBiometrics();

    if (isAuthenticated && mounted) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (context) => const GalleryVaultScreen(),
        ),
      );
    } else if (mounted) {
      setState(() {
        _errorMessage = 'Biometric authentication failed. Please try again.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading || _authMethod == null) {
      return Scaffold(
        backgroundColor: AppColors.lightBackground,
        body: Center(
          child: CircularProgressIndicator(
            color: AppColors.accent,
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: AppColors.lightBackground,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 64),

              // App Icon/Logo
              Center(
                child: Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    color: AppColors.accent,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Icon(
                    Icons.lock_outlined,
                    size: 48,
                    color: Colors.white,
                  ),
                ),
              ),

              const SizedBox(height: 24),

              // App Name
              Text(
                'Locker',
                style: TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.w700,
                  color: AppColors.lightTextPrimary,
                  fontFamily: 'ProductSans',
                ),
                textAlign: TextAlign.center,
              ),

              const SizedBox(height: 8),

              // Unlock instruction
              Text(
                _authMethod == 'pin'
                    ? 'Enter your PIN to unlock'
                    : _authMethod == 'password'
                        ? 'Enter your password to unlock'
                        : 'Use biometrics to unlock',
                style: TextStyle(
                  fontSize: 16,
                  color: AppColors.lightTextSecondary,
                  fontFamily: 'ProductSans',
                ),
                textAlign: TextAlign.center,
              ),

              const SizedBox(height: 64),

              // Authentication Widget based on method
              if (_authMethod == 'pin')
                PinInputWidget(
                  onPinComplete: _handlePinComplete,
                  onPinChanged: _handlePinChanged,
                  errorMessage: _errorMessage,
                )
              else if (_authMethod == 'password')
                Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    TextField(
                      controller: _passwordController,
                      obscureText: _obscurePassword,
                      decoration: InputDecoration(
                        labelText: 'Password',
                        hintText: 'Enter your password',
                        suffixIcon: IconButton(
                          icon: Icon(
                            _obscurePassword
                                ? Icons.visibility_outlined
                                : Icons.visibility_off_outlined,
                            color: AppColors.lightTextTertiary,
                          ),
                          onPressed: () {
                            setState(() {
                              _obscurePassword = !_obscurePassword;
                            });
                          },
                        ),
                      ),
                      style: TextStyle(
                        fontFamily: 'ProductSans',
                        fontSize: 16,
                      ),
                      onChanged: (_) {
                        if (_errorMessage != null) {
                          setState(() {
                            _errorMessage = null;
                          });
                        }
                      },
                      onSubmitted: (_) => _handlePasswordAuth(),
                    ),
                    if (_errorMessage != null) ...[
                      const SizedBox(height: 16),
                      Text(
                        _errorMessage!,
                        style: TextStyle(
                          color: AppColors.error,
                          fontSize: 14,
                          fontFamily: 'ProductSans',
                        ),
                      ),
                    ],
                    const SizedBox(height: 24),
                    ElevatedButton(
                      onPressed: _handlePasswordAuth,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        child: Text(
                          'Unlock',
                          style: TextStyle(
                            fontSize: 16,
                            fontFamily: 'ProductSans',
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                  ],
                )
              else if (_authMethod == 'biometric')
                Column(
                  children: [
                    Container(
                      width: 80,
                      height: 80,
                      decoration: BoxDecoration(
                        color: AppColors.accentLight.withValues(alpha: 0.1),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.fingerprint,
                        size: 48,
                        color: AppColors.accent,
                      ),
                    ),
                    const SizedBox(height: 24),
                    if (_errorMessage != null) ...[
                      Text(
                        _errorMessage!,
                        style: TextStyle(
                          color: AppColors.error,
                          fontSize: 14,
                          fontFamily: 'ProductSans',
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 16),
                    ],
                    ElevatedButton(
                      onPressed: _handleBiometricAuth,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        child: Text(
                          'Unlock with Biometric',
                          style: TextStyle(
                            fontSize: 16,
                            fontFamily: 'ProductSans',
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),

              const Spacer(),
            ],
          ),
        ),
      ),
    );
  }
}
