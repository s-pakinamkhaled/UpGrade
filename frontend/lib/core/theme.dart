import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppTheme {
  // Color Palette (light)
  static const Color primaryBlue = Color(0xFF3b82f6);
  static const Color secondaryPurple = Color(0xFF8b5cf6);
  static const Color darkText = Color(0xFF1e293b);
  static const Color white = Color(0xFFFFFFFF);
  static const Color lightGray = Color(0xFFf1f5f9);
  static const Color mediumGray = Color(0xFFcbd5e1);
  static const Color successGreen = Color(0xFF10b981);
  static const Color warningOrange = Color(0xFFf59e0b);
  static const Color errorRed = Color(0xFFef4444);

  // Dark-mode base colors
  static const Color darkBackground = Color(0xFF0D0D0D);
  static const Color darkSurface = Color(0xFF0F172A);

  static TextTheme _textTheme(Brightness brightness) {
    final base = GoogleFonts.interTextTheme();
    return base.apply(
      bodyColor: brightness == Brightness.dark ? white : darkText,
      displayColor: brightness == Brightness.dark ? white : darkText,
    );
  }

  static ThemeData get lightTheme {
    final textTheme = _textTheme(Brightness.light);
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      colorScheme: const ColorScheme(
        brightness: Brightness.light,
        primary: primaryBlue,
        onPrimary: white,
        secondary: secondaryPurple,
        onSecondary: white,
        error: errorRed,
        onError: white,
        background: lightGray,
        onBackground: darkText,
        surface: white,
        onSurface: darkText,
      ),
      scaffoldBackgroundColor: lightGray,
      textTheme: textTheme,
      appBarTheme: AppBarTheme(
        backgroundColor: white,
        foregroundColor: darkText,
        elevation: 0,
        centerTitle: true,
        surfaceTintColor: Colors.transparent,
        shadowColor: Colors.transparent,
        titleTextStyle: textTheme.titleLarge?.copyWith(
          fontWeight: FontWeight.w600,
          letterSpacing: -0.5,
        ),
        iconTheme: const IconThemeData(color: darkText),
      ),
      cardTheme: const CardThemeData(
        color: white,
        elevation: 0,
        margin: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: white,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: mediumGray),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: mediumGray),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: primaryBlue, width: 2),
        ),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primaryBlue,
          foregroundColor: white,
          elevation: 0,
          padding:
              const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          textStyle: textTheme.labelLarge?.copyWith(
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: primaryBlue,
          textStyle: textTheme.labelLarge?.copyWith(
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      pageTransitionsTheme: const PageTransitionsTheme(
        builders: {
          TargetPlatform.android: _UpGradePageTransitionBuilder(),
          TargetPlatform.iOS: _UpGradePageTransitionBuilder(),
          TargetPlatform.windows: _UpGradePageTransitionBuilder(),
          TargetPlatform.macOS: _UpGradePageTransitionBuilder(),
          TargetPlatform.linux: _UpGradePageTransitionBuilder(),
        },
      ),
    );
  }

  static ThemeData get darkTheme {
    final textTheme = _textTheme(Brightness.dark);
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: const ColorScheme(
        brightness: Brightness.dark,
        primary: primaryBlue,
        onPrimary: white,
        secondary: secondaryPurple,
        onSecondary: white,
        error: errorRed,
        onError: white,
        background: darkBackground,
        onBackground: white,
        surface: darkSurface,
        onSurface: white,
      ),
      scaffoldBackgroundColor: darkBackground,
      textTheme: textTheme,
      appBarTheme: AppBarTheme(
        backgroundColor: darkSurface,
        foregroundColor: white,
        elevation: 0,
        centerTitle: true,
        surfaceTintColor: Colors.transparent,
        shadowColor: Colors.transparent,
        titleTextStyle: textTheme.titleLarge?.copyWith(
          fontWeight: FontWeight.w600,
          letterSpacing: -0.5,
        ),
        iconTheme: const IconThemeData(color: white),
      ),
      cardTheme: const CardThemeData(
        color: darkSurface,
        elevation: 0,
        margin: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: const Color(0xFF020617),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: mediumGray),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: mediumGray),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: primaryBlue, width: 2),
        ),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primaryBlue,
          foregroundColor: white,
          elevation: 0,
          padding:
              const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          textStyle: textTheme.labelLarge?.copyWith(
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: primaryBlue,
          textStyle: textTheme.labelLarge?.copyWith(
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      pageTransitionsTheme: const PageTransitionsTheme(
        builders: {
          TargetPlatform.android: _UpGradePageTransitionBuilder(),
          TargetPlatform.iOS: _UpGradePageTransitionBuilder(),
          TargetPlatform.windows: _UpGradePageTransitionBuilder(),
          TargetPlatform.macOS: _UpGradePageTransitionBuilder(),
          TargetPlatform.linux: _UpGradePageTransitionBuilder(),
        },
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

class _UpGradePageTransitionBuilder extends PageTransitionsBuilder {
  const _UpGradePageTransitionBuilder();

  @override
  Widget buildTransitions<T>(
    PageRoute<T> route,
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    final curved = CurvedAnimation(
      parent: animation,
      curve: Curves.easeOutCubic,
      reverseCurve: Curves.easeInCubic,
    );

    return FadeTransition(
      opacity: curved,
      child: SlideTransition(
        position: Tween<Offset>(
          begin: const Offset(0, 0.04),
          end: Offset.zero,
        ).animate(curved),
        child: child,
      ),
    );
  }
}

