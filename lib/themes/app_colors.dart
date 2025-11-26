import 'package:flutter/material.dart';

/// App Color Palette
/// Contains all color definitions used throughout the Locker app
class AppColors {
  AppColors._(); // Private constructor to prevent instantiation

  // ===== PRIMARY COLORS =====

  /// Main background color - Dark Gray (#121212)
  static const Color primaryBackground = Color(0xFF121212);

  /// Main text color - Light Gray (#F5F5F5)
  static const Color primaryText = Color(0xFFF5F5F5);

  // ===== BACKGROUND VARIATIONS =====

  /// Darker variation of primary background
  static const Color backgroundDark = Color(0xFF0A0A0A);

  /// Slightly lighter variation of primary background
  static const Color backgroundLight = Color(0xFF1E1E1E);

  /// Surface color for cards, containers
  static const Color surface = Color(0xFF262626);

  /// Elevated surface color
  static const Color surfaceElevated = Color(0xFF2D2D2D);

  // ===== TEXT VARIATIONS =====

  /// Primary text color (same as primaryText for consistency)
  static const Color textPrimary = Color(0xFFF5F5F5);

  /// Secondary text color - slightly dimmed
  static const Color textSecondary = Color(0xFFE0E0E0);

  /// Tertiary text color - more dimmed
  static const Color textTertiary = Color(0xFFBDBDBD);

  /// Disabled text color
  static const Color textDisabled = Color(0xFF757575);

  /// Hint text color
  static const Color textHint = Color(0xFF9E9E9E);

  // ===== ACCENT COLORS =====

  /// Success color
  static const Color success = Color(0xFF4CAF50);

  /// Error color
  static const Color error = Color(0xFFE53935);

  /// Warning color
  static const Color warning = Color(0xFFFF9800);

  /// Info color
  static const Color info = Color(0xFF2196F3);

  // ===== UTILITY COLORS =====

  /// Divider color
  static const Color divider = Color(0xFF424242);

  /// Border color
  static const Color border = Color(0xFF616161);

  /// Shadow color
  static const Color shadow = Color(0xFF000000);

  /// Overlay color (for modals, dialogs)
  static const Color overlay = Color(0x80000000);

  // ===== LIGHT THEME COLORS =====

  /// Light theme background
  static const Color lightBackground = Color(0xFFFFFFFF);

  /// Light theme secondary background
  static const Color lightBackgroundSecondary = Color(0xFFF8F9FA);

  /// Light theme surface
  static const Color lightSurface = Color(0xFFFFFFFF);

  /// Light theme text primary
  static const Color lightTextPrimary = Color(0xFF212121);

  /// Light theme text secondary
  static const Color lightTextSecondary = Color(0xFF424242);

  /// Light theme text tertiary
  static const Color lightTextTertiary = Color(0xFF757575);

  /// Light theme divider
  static const Color lightDivider = Color(0xFFE0E0E0);

  /// Light theme border
  static const Color lightBorder = Color(0xFFBDBDBD);

  /// Light theme accent color
  static const Color accent = Color(0xFF1976D2);

  /// Light theme accent light
  static const Color accentLight = Color(0xFF42A5F5);

  // ===== GRADIENTS =====

  /// Primary background gradient
  static const LinearGradient backgroundGradient = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [
      Color(0xFF121212),
      Color(0xFF1E1E1E),
    ],
  );

  /// Card gradient
  static const LinearGradient cardGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [
      Color(0xFF262626),
      Color(0xFF1E1E1E),
    ],
  );

  // ===== MATERIAL COLOR SWATCHES =====

  /// Primary material color swatch based on the background color
  static const MaterialColor primarySwatch = MaterialColor(
    0xFF121212,
    <int, Color>{
      50: Color(0xFFE8E8E8),
      100: Color(0xFFC6C6C6),
      200: Color(0xFFA0A0A0),
      300: Color(0xFF7A7A7A),
      400: Color(0xFF5E5E5E),
      500: Color(0xFF424242),
      600: Color(0xFF3C3C3C),
      700: Color(0xFF333333),
      800: Color(0xFF2A2A2A),
      900: Color(0xFF121212),
    },
  );

  /// Text material color swatch based on the text color
  static const MaterialColor textSwatch = MaterialColor(
    0xFFF5F5F5,
    <int, Color>{
      50: Color(0xFFFFFFFF),
      100: Color(0xFFFAFAFA),
      200: Color(0xFFF5F5F5),
      300: Color(0xFFE0E0E0),
      400: Color(0xFFBDBDBD),
      500: Color(0xFF9E9E9E),
      600: Color(0xFF757575),
      700: Color(0xFF616161),
      800: Color(0xFF424242),
      900: Color(0xFF212121),
    },
  );

  // ===== COLOR SCHEMES =====

  /// Light color scheme (for future use)
  static const ColorScheme lightColorScheme = ColorScheme.light(
    primary: Color(0xFF121212),
    primaryContainer: Color(0xFF262626),
    secondary: Color(0xFFF5F5F5),
    secondaryContainer: Color(0xFFE0E0E0),
    surface: Color(0xFFFFFFFF),
    error: Color(0xFFE53935),
    onPrimary: Color(0xFFF5F5F5),
    onSecondary: Color(0xFF121212),
    onSurface: Color(0xFF121212),
    onError: Color(0xFFFFFFFF),
  );

  /// Dark color scheme (main theme)
  static const ColorScheme darkColorScheme = ColorScheme.dark(
    primary: Color(0xFFF5F5F5),
    primaryContainer: Color(0xFF262626),
    secondary: Color(0xFF121212),
    secondaryContainer: Color(0xFF1E1E1E),
    surface: Color(0xFF262626),
    error: Color(0xFFE53935),
    onPrimary: Color(0xFF121212),
    onSecondary: Color(0xFFF5F5F5),
    onSurface: Color(0xFFF5F5F5),
    onError: Color(0xFFFFFFFF),
  );
}
