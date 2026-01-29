import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

/// Cupertino-inspired dark theme (3D Object Builder style).
/// Charcoal background, subtle depth, rounded corners, clean typography.
class AppTheme {
  static const Color _background = Color(0xFF0C0D14);
  static const Color _surface = Color(0xFF1C1C1E);
  static const Color _surfaceVariant = Color(0xFF2C2C2E);
  static const Color _primary = Color(0xFF0A84FF);

  static ThemeData get darkTheme {
    const colorScheme = ColorScheme.dark(
      surface: _surface,
      onSurface: CupertinoColors.white,
      onSurfaceVariant: Color(0xFF8E8E93),
      primary: _primary,
      onPrimary: CupertinoColors.white,
      secondary: Color(0xFF5E5CE6),
      outline: Color(0xFF48484A),
    );

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: _background,
      cupertinoOverrideTheme: const CupertinoThemeData(
        brightness: Brightness.dark,
        primaryColor: _primary,
        scaffoldBackgroundColor: _background,
        barBackgroundColor: _surface,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: true,
        titleTextStyle: TextStyle(
          color: CupertinoColors.white,
          fontSize: 17,
          fontWeight: FontWeight.w600,
        ),
        iconTheme: IconThemeData(color: CupertinoColors.white),
      ),
      cardTheme: CardThemeData(
        color: _surfaceVariant.withValues(alpha: 0.6),
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: _surfaceVariant,
        labelStyle: const TextStyle(color: CupertinoColors.white),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: _surfaceVariant,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: _surfaceVariant,
          foregroundColor: CupertinoColors.white,
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: _surfaceVariant,
          foregroundColor: CupertinoColors.white,
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
      ),
      textTheme: const TextTheme(
        headlineSmall: TextStyle(
          color: CupertinoColors.white,
          fontWeight: FontWeight.bold,
          fontSize: 22,
        ),
        titleLarge: TextStyle(
          color: CupertinoColors.white,
          fontWeight: FontWeight.w600,
          fontSize: 17,
        ),
        titleMedium: TextStyle(
          color: CupertinoColors.white,
          fontWeight: FontWeight.w500,
          fontSize: 15,
        ),
        bodyMedium: TextStyle(
          color: Color(0xFF8E8E93),
          fontSize: 15,
        ),
      ),
    );
  }
}
