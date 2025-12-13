import 'package:flutter/material.dart';
import 'package:local_auth/local_auth.dart';
import '../services/auth_service.dart';
import '../utils/toast_utils.dart';
import 'gallery_vault_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with WidgetsBindingObserver {
  final AuthService _authService = AuthService();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _confirmPasswordController =
      TextEditingController();

  bool _isLoading = true;
  bool _isFirstTime = true;
  bool _isPasswordVisible = false;
  bool _isConfirmPasswordVisible = false;
  bool _isBiometricAvailable = false;
  bool _isBiometricEnabled = false;
  List<BiometricType> _availableBiometrics = [];
  String _biometricDisplayName = '';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initialize();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _checkBiometricState();
    }
  }

  Future<void> _initialize() async {
    await _checkAuthState();
    await _checkBiometricState();
    setState(() {
      _isLoading = false;
    });
  }

  Future<void> _checkAuthState() async {
    final isFirstTime = await _authService.isFirstTime();
    setState(() {
      _isFirstTime = isFirstTime;
    });
  }

  Future<void> _checkBiometricState() async {
    final isAvailable = await _authService.isBiometricAvailable();
    final isEnabled = await _authService.isBiometricEnabled();
    final biometrics = await _authService.getAvailableBiometrics();
    final displayName = _authService.getBiometricDisplayName(biometrics);

    setState(() {
      _isBiometricAvailable = isAvailable;
      _isBiometricEnabled = isEnabled;
      _availableBiometrics = biometrics;
      _biometricDisplayName = displayName;
    });
  }

  Future<void> _createPassword() async {
    final password = _passwordController.text.trim();
    final confirmPassword = _confirmPasswordController.text.trim();

    if (password.isEmpty) {
      ToastUtils.showError('Please enter a password');
      return;
    }

    if (password.length < 6) {
      ToastUtils.showError('Password must be at least 6 characters');
      return;
    }

    if (password != confirmPassword) {
      ToastUtils.showError('Passwords do not match');
      return;
    }

    setState(() {
      _isLoading = true;
    });

    final success = await _authService.createPassword(password);
    if (success) {
      ToastUtils.showSuccess('Password created successfully');
      _passwordController.clear();
      _confirmPasswordController.clear();

      // Check if user wants to set up biometrics
      if (_isBiometricAvailable) {
        _showBiometricSetupDialog();
      } else {
        _navigateToMainApp();
      }
    } else {
      ToastUtils.showError('Failed to create password');
    }

    setState(() {
      _isLoading = false;
    });
  }

  Future<void> _authenticateWithPassword() async {
    final password = _passwordController.text.trim();

    if (password.isEmpty) {
      ToastUtils.showError('Please enter your password');
      return;
    }

    setState(() {
      _isLoading = true;
    });

    final success = await _authService.verifyPassword(password);
    if (success) {
      _passwordController.clear();
      _navigateToMainApp();
    } else {
      ToastUtils.showError('Incorrect password');
      // Clear password field for security
      _passwordController.clear();
    }

    setState(() {
      _isLoading = false;
    });
  }

  Future<void> _authenticateWithBiometrics() async {
    setState(() {
      _isLoading = true;
    });

    final success = await _authService.authenticateWithBiometrics();
    if (success) {
      _navigateToMainApp();
    } else {
      ToastUtils.showError('Biometric authentication failed');
    }

    setState(() {
      _isLoading = false;
    });
  }

  void _showBiometricSetupDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Set up $_biometricDisplayName'),
        content: Text(
          'Would you like to enable $_biometricDisplayName authentication for faster login?',
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              _navigateToMainApp();
            },
            child: const Text('Not now'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.of(context).pop();
              await _setupBiometrics();
            },
            child: const Text('Set up'),
          ),
        ],
      ),
    );
  }

  Future<void> _setupBiometrics() async {
    setState(() {
      _isLoading = true;
    });

    final success = await _authService.setupBiometricAuthentication();
    if (success) {
      ToastUtils.showSuccess('$_biometricDisplayName enabled successfully');
      await _checkBiometricState();
    } else {
      ToastUtils.showError('Failed to enable $_biometricDisplayName');
    }

    setState(() {
      _isLoading = false;
    });

    _navigateToMainApp();
  }

  void _navigateToMainApp() {
    // Navigate to the main gallery vault screen
    // Using pushReplacement to prevent going back to login screen
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (context) => const GalleryVaultScreen(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: const [
              CircularProgressIndicator(),
              SizedBox(height: 16),
              Text('Loading...'),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // App Logo/Title
              Image.asset(
                'assets/padlock.png',
                width: 100,
                height: 100,
              ),
              const SizedBox(height: 16),
              Text(
                'Locker',
                style: Theme.of(context).textTheme.headlineLarge,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                _isFirstTime
                    ? 'Create your secure password'
                    : 'Enter your password to continue',
                style: Theme.of(context).textTheme.bodyLarge,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 48),

              // Password Input
              TextField(
                controller: _passwordController,
                obscureText: !_isPasswordVisible,
                decoration: InputDecoration(
                  labelText: _isFirstTime ? 'Create Password' : 'Password',
                  prefixIcon: const Icon(Icons.lock_outline),
                  suffixIcon: IconButton(
                    icon: Icon(_isPasswordVisible
                        ? Icons.visibility_off
                        : Icons.visibility),
                    onPressed: () {
                      setState(() {
                        _isPasswordVisible = !_isPasswordVisible;
                      });
                    },
                  ),
                ),
                onSubmitted: _isFirstTime
                    ? null
                    : (value) => _authenticateWithPassword(),
              ),
              const SizedBox(height: 16),

              // Confirm Password Input (only for first time)
              if (_isFirstTime) ...[
                TextField(
                  controller: _confirmPasswordController,
                  obscureText: !_isConfirmPasswordVisible,
                  decoration: InputDecoration(
                    labelText: 'Confirm Password',
                    prefixIcon: const Icon(Icons.lock_outline),
                    suffixIcon: IconButton(
                      icon: Icon(_isConfirmPasswordVisible
                          ? Icons.visibility_off
                          : Icons.visibility),
                      onPressed: () {
                        setState(() {
                          _isConfirmPasswordVisible =
                              !_isConfirmPasswordVisible;
                        });
                      },
                    ),
                  ),
                  onSubmitted: (value) => _createPassword(),
                ),
                const SizedBox(height: 32),
              ] else ...[
                const SizedBox(height: 32),
              ],

              // Primary Action Button
              ElevatedButton(
                onPressed:
                    _isFirstTime ? _createPassword : _authenticateWithPassword,
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  child: Text(
                    _isFirstTime ? 'Create Password' : 'Unlock',
                    style: const TextStyle(fontSize: 16),
                  ),
                ),
              ),

              // Biometric Authentication Button (only if available and not first time)
              if (!_isFirstTime &&
                  _isBiometricAvailable &&
                  _isBiometricEnabled) ...[
                const SizedBox(height: 16),
                const Row(
                  children: [
                    Expanded(child: Divider()),
                    Padding(
                      padding: EdgeInsets.symmetric(horizontal: 16),
                      child: Text('OR'),
                    ),
                    Expanded(child: Divider()),
                  ],
                ),
                const SizedBox(height: 16),
                OutlinedButton.icon(
                  onPressed: _authenticateWithBiometrics,
                  icon: Icon(_getBiometricIcon()),
                  label: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    child: Text('Use $_biometricDisplayName'),
                  ),
                ),
              ],

              // Helper Text
              if (_isFirstTime) ...[
                const SizedBox(height: 24),
                Text(
                  'Your password will be securely encrypted and stored locally on your device.',
                  style: Theme.of(context).textTheme.bodySmall,
                  textAlign: TextAlign.center,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  IconData _getBiometricIcon() {
    if (_availableBiometrics.contains(BiometricType.fingerprint)) {
      return Icons.fingerprint;
    } else if (_availableBiometrics.contains(BiometricType.face)) {
      return Icons.face;
    } else {
      return Icons.security;
    }
  }
}
