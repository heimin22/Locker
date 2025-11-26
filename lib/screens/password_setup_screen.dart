import 'package:flutter/material.dart';
import '../themes/app_colors.dart';
import '../services/auth_service.dart';
import 'gallery_vault_screen.dart';

/// Password setup screen with confirmation
class PasswordSetupScreen extends StatefulWidget {
  const PasswordSetupScreen({super.key});

  @override
  State<PasswordSetupScreen> createState() => _PasswordSetupScreenState();
}

class _PasswordSetupScreenState extends State<PasswordSetupScreen> {
  final AuthService _authService = AuthService();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _confirmPasswordController =
      TextEditingController();
  bool _isConfirmation = false;
  String? _errorMessage;
  bool _isLoading = false;
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;

  @override
  void dispose() {
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _handleContinue() async {
    final password = _passwordController.text;

    if (password.isEmpty) {
      setState(() {
        _errorMessage = 'Please enter a password';
      });
      return;
    }

    if (!_isConfirmation) {
      // Move to confirmation
      setState(() {
        _isConfirmation = true;
        _errorMessage = null;
      });
    } else {
      // Verify confirmation
      final confirmPassword = _confirmPasswordController.text;

      if (confirmPassword != password) {
        setState(() {
          _errorMessage = 'Passwords do not match';
        });
        return;
      }

      // Save password
      setState(() {
        _isLoading = true;
        _errorMessage = null;
      });

      final success = await _authService.createPassword(password);

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
          _errorMessage = 'Failed to save password. Please try again.';
        });
      }
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
                    // Go back to password entry
                    setState(() {
                      _isConfirmation = false;
                      _confirmPasswordController.clear();
                      _errorMessage = null;
                    });
                  } else {
                    Navigator.pop(context);
                  }
                },
        ),
        title: Text(
          _isConfirmation ? 'Confirm Password' : 'Create Password',
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
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const SizedBox(height: 32),

                    // Instruction Text
                    Text(
                      _isConfirmation
                          ? 'Enter your password again to confirm'
                          : 'Create a secure password',
                      style: TextStyle(
                        fontSize: 18,
                        color: AppColors.lightTextSecondary,
                        fontFamily: 'ProductSans',
                      ),
                      textAlign: TextAlign.center,
                    ),

                    const SizedBox(height: 48),

                    // Password Input Field
                    if (!_isConfirmation)
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
                      ),

                    // Confirmation Password Input Field
                    if (_isConfirmation)
                      TextField(
                        controller: _confirmPasswordController,
                        obscureText: _obscureConfirmPassword,
                        decoration: InputDecoration(
                          labelText: 'Confirm Password',
                          hintText: 'Re-enter your password',
                          suffixIcon: IconButton(
                            icon: Icon(
                              _obscureConfirmPassword
                                  ? Icons.visibility_outlined
                                  : Icons.visibility_off_outlined,
                              color: AppColors.lightTextTertiary,
                            ),
                            onPressed: () {
                              setState(() {
                                _obscureConfirmPassword =
                                    !_obscureConfirmPassword;
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
                      ),

                    const SizedBox(height: 16),

                    // Error Message
                    if (_errorMessage != null)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 16),
                        child: Text(
                          _errorMessage!,
                          style: TextStyle(
                            color: AppColors.error,
                            fontSize: 14,
                            fontFamily: 'ProductSans',
                          ),
                        ),
                      ),

                    const Spacer(),

                    // Continue Button
                    ElevatedButton(
                      onPressed: _handleContinue,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        child: Text(
                          _isConfirmation ? 'Confirm' : 'Continue',
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
