import 'package:flutter/material.dart';
import 'themes/app_theme.dart';
import 'services/auth_service.dart';
import 'screens/auth_method_selection_screen.dart';
import 'screens/unlock_screen.dart';

void main() => runApp(const LockerApp());

class LockerApp extends StatelessWidget {
  const LockerApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Locker',
      theme: AppTheme.lightTheme,
      themeMode: AppTheme.themeMode,
      home: const AppInitializer(),
    );
  }
}

/// Initialize app and determine initial route based on authentication state
class AppInitializer extends StatefulWidget {
  const AppInitializer({super.key});

  @override
  State<AppInitializer> createState() => _AppInitializerState();
}

class _AppInitializerState extends State<AppInitializer> {
  final AuthService _authService = AuthService();
  bool _isLoading = true;
  bool _isFirstTime = true;

  @override
  void initState() {
    super.initState();
    _checkAuthStatus();
  }

  Future<void> _checkAuthStatus() async {
    final isFirstTime = await _authService.isFirstTime();

    setState(() {
      _isFirstTime = isFirstTime;
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        backgroundColor: Colors.white,
        body: Center(
          child: CircularProgressIndicator(
            color: Color(0xFF1976D2),
          ),
        ),
      );
    }

    // Route to appropriate screen
    if (_isFirstTime) {
      return const AuthMethodSelectionScreen();
    } else {
      return const UnlockScreen();
    }
  }
}
