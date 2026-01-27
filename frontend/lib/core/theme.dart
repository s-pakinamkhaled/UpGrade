import 'package:flutter/material.dart';
import 'constants.dart';

class AppTheme {
  // Color Palette
  static const Color primaryBlue = Color(0xFF3b82f6);
  static const Color secondaryPurple = Color(0xFF8b5cf6);
  static const Color darkText = Color(0xFF1e293b);
  static const Color white = Color(0xFFFFFFFF);
  static const Color lightGray = Color(0xFFf1f5f9);
  static const Color mediumGray = Color(0xFFcbd5e1);
  static const Color successGreen = Color(0xFF10b981);
  static const Color warningOrange = Color(0xFFf59e0b);
  static const Color errorRed = Color(0xFFef4444);

  static ThemeData get lightTheme {
    return ThemeData(
      useMaterial3: true,

      colorScheme: ColorScheme.fromSeed(
        seedColor: primaryBlue,
        primary: primaryBlue,
        secondary: secondaryPurple,
        surface: white,
        onSurface: darkText,
      ),

      scaffoldBackgroundColor: lightGray,

      // AppBar
      appBarTheme: const AppBarTheme(
        backgroundColor: white,
        foregroundColor: darkText,
        elevation: 0,
        centerTitle: true,
        surfaceTintColor: Colors.transparent,
        shadowColor: Colors.transparent,
        titleTextStyle: TextStyle(
          color: darkText,
          fontSize: 20,
          fontWeight: FontWeight.w600,
          letterSpacing: -0.5,
        ),
        iconTheme: IconThemeData(color: darkText),
      ),

      // ✅ FIXED: CardThemeData (Material 3)
      cardTheme: const CardThemeData(
        color: white,
        elevation: 0,
        margin: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      ),

      // Inputs
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: white,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: mediumGray),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: mediumGray),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: primaryBlue, width: 2),
        ),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      ),

      // Buttons
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primaryBlue,
          foregroundColor: white,
          elevation: 0,
          padding:
              const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          textStyle: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),

      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: primaryBlue,
          textStyle: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),

      // Typography
      textTheme: const TextTheme(
        displayLarge: TextStyle(
            color: darkText, fontSize: 32, fontWeight: FontWeight.bold),
        displayMedium: TextStyle(
            color: darkText, fontSize: 28, fontWeight: FontWeight.bold),
        displaySmall: TextStyle(
            color: darkText, fontSize: 24, fontWeight: FontWeight.bold),
        headlineMedium: TextStyle(
            color: darkText, fontSize: 20, fontWeight: FontWeight.w600),
        titleLarge: TextStyle(
            color: darkText, fontSize: 18, fontWeight: FontWeight.w600),
        titleMedium: TextStyle(
            color: darkText, fontSize: 16, fontWeight: FontWeight.w600),
        bodyLarge: TextStyle(color: darkText, fontSize: 16),
        bodyMedium: TextStyle(color: darkText, fontSize: 14),
        bodySmall: TextStyle(color: darkText, fontSize: 12),
      ),
    );
  }

  // Gradients
  static LinearGradient get primaryGradient => const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [primaryBlue, secondaryPurple],
      );

  static LinearGradient get softGradient => LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          primaryBlue.withOpacity(0.1),
          secondaryPurple.withOpacity(0.1),
        ],
      );

  static LinearGradient get accentGradient => LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          primaryBlue.withOpacity(0.15),
          secondaryPurple.withOpacity(0.15),
        ],
      );

  // Shadows
  static List<BoxShadow> get softShadow => [
        BoxShadow(
          color: primaryBlue.withOpacity(0.08),
          blurRadius: 10,
          offset: const Offset(0, 2),
        ),
      ];

  static List<BoxShadow> get mediumShadow => [
        BoxShadow(
          color: primaryBlue.withOpacity(0.12),
          blurRadius: 16,
          offset: const Offset(0, 4),
        ),
      ];

  static List<BoxShadow> get strongShadow => [
        BoxShadow(
          color: primaryBlue.withOpacity(0.2),
          blurRadius: 24,
          offset: const Offset(0, 8),
        ),
      ];
}
