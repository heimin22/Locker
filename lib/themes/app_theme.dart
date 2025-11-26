import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'app_colors.dart';

/// App Theme Configuration
/// Provides light and dark theme configurations for the Locker app
class AppTheme {
  AppTheme._(); // Private constructor to prevent instantiation

  // ===== DARK THEME (PRIMARY) =====

  static ThemeData get darkTheme {
    return ThemeData(
      useMaterial3: true,
      colorScheme: AppColors.darkColorScheme,
      primarySwatch: AppColors.primarySwatch,

      // Background
      scaffoldBackgroundColor: AppColors.primaryBackground,
      canvasColor: AppColors.primaryBackground,

      // Typography
      fontFamily: 'ProductSans',
      textTheme: _buildTextTheme(AppColors.primaryText),

      // App Bar
      appBarTheme: AppBarTheme(
        backgroundColor: AppColors.surface,
        foregroundColor: AppColors.primaryText,
        elevation: 0,
        centerTitle: true,
        titleTextStyle: TextStyle(
          color: AppColors.primaryText,
          fontSize: 20,
          fontWeight: FontWeight.w600,
          fontFamily: 'ProductSans',
        ),
        systemOverlayStyle: SystemUiOverlayStyle(
          statusBarColor: Colors.transparent,
          statusBarIconBrightness: Brightness.light,
          statusBarBrightness: Brightness.dark,
        ),
      ),

      // Elevated Button
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.surface,
          foregroundColor: AppColors.primaryText,
          elevation: 2,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
          padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        ),
      ),

      // Text Button
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: AppColors.primaryText,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
        ),
      ),

      // Outlined Button
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.primaryText,
          side: BorderSide(color: AppColors.border),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
        ),
      ),

      // Floating Action Button
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: AppColors.surface,
        foregroundColor: AppColors.primaryText,
        elevation: 4,
        shape: CircleBorder(),
      ),

      // Card
      cardTheme: CardThemeData(
        color: AppColors.surface,
        elevation: 2,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        margin: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      ),

      // Input Decoration
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.surface,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: AppColors.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: AppColors.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: AppColors.primaryText, width: 2),
        ),
        labelStyle: TextStyle(color: AppColors.textSecondary),
        hintStyle: TextStyle(color: AppColors.textHint),
      ),

      // Bottom Navigation Bar
      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        backgroundColor: AppColors.surface,
        selectedItemColor: AppColors.primaryText,
        unselectedItemColor: AppColors.textTertiary,
        type: BottomNavigationBarType.fixed,
        elevation: 8,
      ),

      // Divider
      dividerTheme: DividerThemeData(
        color: AppColors.divider,
        thickness: 1,
      ),

      // Dialog
      dialogTheme: DialogThemeData(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        titleTextStyle: TextStyle(
          color: AppColors.primaryText,
          fontSize: 20,
          fontWeight: FontWeight.w600,
        ),
        contentTextStyle: TextStyle(
          color: AppColors.textSecondary,
          fontSize: 16,
        ),
      ),

      // Bottom Sheet
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
        ),
      ),

      // Switch
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return AppColors.primaryText;
          }
          return AppColors.textTertiary;
        }),
        trackColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return AppColors.surface;
          }
          return AppColors.divider;
        }),
      ),

      // Icon
      iconTheme: IconThemeData(
        color: AppColors.primaryText,
        size: 24,
      ),

      // Primary Icon
      primaryIconTheme: IconThemeData(
        color: AppColors.primaryText,
        size: 24,
      ),

      // Checkbox
      checkboxTheme: CheckboxThemeData(
        fillColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return AppColors.primaryText;
          }
          return Colors.transparent;
        }),
        checkColor: WidgetStateProperty.all(AppColors.primaryBackground),
        side: BorderSide(color: AppColors.border),
      ),

      // Radio
      radioTheme: RadioThemeData(
        fillColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return AppColors.primaryText;
          }
          return AppColors.border;
        }),
      ),

      // Slider
      sliderTheme: SliderThemeData(
        activeTrackColor: AppColors.primaryText,
        inactiveTrackColor: AppColors.divider,
        thumbColor: AppColors.primaryText,
        overlayColor: AppColors.primaryText.withValues(alpha: 0.2),
      ),
    );
  }

  // ===== LIGHT THEME (OPTIONAL) =====

  static ThemeData get lightTheme {
    return ThemeData(
      useMaterial3: true,
      colorScheme: AppColors.lightColorScheme,
      primarySwatch: AppColors.textSwatch,

      // Background
      scaffoldBackgroundColor: AppColors.lightBackground,
      canvasColor: AppColors.lightBackground,

      // Typography
      fontFamily: 'ProductSans',
      textTheme: _buildTextTheme(AppColors.lightTextPrimary),

      // App Bar
      appBarTheme: AppBarTheme(
        backgroundColor: AppColors.lightBackground,
        foregroundColor: AppColors.lightTextPrimary,
        elevation: 0,
        centerTitle: true,
        titleTextStyle: TextStyle(
          color: AppColors.lightTextPrimary,
          fontSize: 20,
          fontWeight: FontWeight.w600,
          fontFamily: 'ProductSans',
        ),
        systemOverlayStyle: SystemUiOverlayStyle(
          statusBarColor: Colors.transparent,
          statusBarIconBrightness: Brightness.dark,
          statusBarBrightness: Brightness.light,
        ),
      ),

      // Elevated Button
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.accent,
          foregroundColor: Colors.white,
          elevation: 2,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          padding: EdgeInsets.symmetric(horizontal: 24, vertical: 16),
        ),
      ),

      // Text Button
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: AppColors.accent,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),

      // Outlined Button
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.lightTextPrimary,
          side: BorderSide(color: AppColors.lightBorder),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),

      // Card
      cardTheme: CardThemeData(
        color: AppColors.lightSurface,
        elevation: 2,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        margin: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      ),

      // Input Decoration
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.lightBackgroundSecondary,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: AppColors.lightBorder),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: AppColors.lightBorder),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: AppColors.accent, width: 2),
        ),
        labelStyle: TextStyle(color: AppColors.lightTextSecondary),
        hintStyle: TextStyle(color: AppColors.lightTextTertiary),
      ),

      // Icon
      iconTheme: IconThemeData(
        color: AppColors.lightTextPrimary,
        size: 24,
      ),

      // Dialog
      dialogTheme: DialogThemeData(
        backgroundColor: AppColors.lightSurface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        titleTextStyle: TextStyle(
          color: AppColors.lightTextPrimary,
          fontSize: 20,
          fontWeight: FontWeight.w600,
        ),
        contentTextStyle: TextStyle(
          color: AppColors.lightTextSecondary,
          fontSize: 16,
        ),
      ),
    );
  }

  // ===== HELPER METHODS =====

  /// Builds text theme with the specified color
  static TextTheme _buildTextTheme(Color textColor) {
    return TextTheme(
      displayLarge: TextStyle(
        color: textColor,
        fontSize: 57,
        fontWeight: FontWeight.w400,
        fontFamily: 'ProductSans',
      ),
      displayMedium: TextStyle(
        color: textColor,
        fontSize: 45,
        fontWeight: FontWeight.w400,
        fontFamily: 'ProductSans',
      ),
      displaySmall: TextStyle(
        color: textColor,
        fontSize: 36,
        fontWeight: FontWeight.w400,
        fontFamily: 'ProductSans',
      ),
      headlineLarge: TextStyle(
        color: textColor,
        fontSize: 32,
        fontWeight: FontWeight.w600,
        fontFamily: 'ProductSans',
      ),
      headlineMedium: TextStyle(
        color: textColor,
        fontSize: 28,
        fontWeight: FontWeight.w600,
        fontFamily: 'ProductSans',
      ),
      headlineSmall: TextStyle(
        color: textColor,
        fontSize: 24,
        fontWeight: FontWeight.w600,
        fontFamily: 'ProductSans',
      ),
      titleLarge: TextStyle(
        color: textColor,
        fontSize: 22,
        fontWeight: FontWeight.w500,
        fontFamily: 'ProductSans',
      ),
      titleMedium: TextStyle(
        color: textColor,
        fontSize: 16,
        fontWeight: FontWeight.w500,
        fontFamily: 'ProductSans',
      ),
      titleSmall: TextStyle(
        color: textColor,
        fontSize: 14,
        fontWeight: FontWeight.w500,
        fontFamily: 'ProductSans',
      ),
      bodyLarge: TextStyle(
        color: textColor,
        fontSize: 16,
        fontWeight: FontWeight.w400,
        fontFamily: 'ProductSans',
      ),
      bodyMedium: TextStyle(
        color: textColor,
        fontSize: 14,
        fontWeight: FontWeight.w400,
        fontFamily: 'ProductSans',
      ),
      bodySmall: TextStyle(
        color: textColor,
        fontSize: 12,
        fontWeight: FontWeight.w400,
        fontFamily: 'ProductSans',
      ),
      labelLarge: TextStyle(
        color: textColor,
        fontSize: 14,
        fontWeight: FontWeight.w500,
        fontFamily: 'ProductSans',
      ),
      labelMedium: TextStyle(
        color: textColor,
        fontSize: 12,
        fontWeight: FontWeight.w500,
        fontFamily: 'ProductSans',
      ),
      labelSmall: TextStyle(
        color: textColor,
        fontSize: 11,
        fontWeight: FontWeight.w500,
        fontFamily: 'ProductSans',
      ),
    );
  }

  /// Returns the current theme mode preference
  static ThemeMode get themeMode => ThemeMode.light; // Default to light theme
}
