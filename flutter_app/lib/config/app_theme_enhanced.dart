import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Modern, vibrant app theme with animations and responsive design
class AppThemeEnhanced {
  // ===== Color Palette =====
  // Primary Gradient Colors
  static const Color primary = Color(0xFFFF6B35);      // Vibrant Orange
  static const Color primaryLight = Color(0xFFFF8C5A);
  static const Color primaryDark = Color(0xFFE55100);

  // Secondary Gradient Colors
  static const Color secondary = Color(0xFF004E89);    // Deep Blue
  static const Color secondaryLight = Color(0xFF1B6DAD);
  static const Color secondaryDark = Color(0xFF003366);

  // Accent Colors
  static const Color accent = Color(0xFF00D4FF);       // Cyan
  static const Color accentGreen = Color(0xFF00D084);  // Emerald
  static const Color accentPurple = Color(0xFFBB00FF); // Purple

  // Neutral Colors
  static const Color background = Color(0xFF0A0E27);   // Deep Dark Blue
  static const Color surface = Color(0xFF1A1F3A);
  static const Color surfaceLight = Color(0xFF252F4A);
  static const Color surfaceHighest = Color(0xFF3A4A6F);

  // Text Colors
  static const Color textPrimary = Color(0xFFFBF8FF);
  static const Color textSecondary = Color(0xFFB0B8D4);
  static const Color textMuted = Color(0xFF8089A8);

  // Status Colors
  static const Color success = Color(0xFF00D084);
  static const Color warning = Color(0xFFFFAA00);
  static const Color error = Color(0xFFFF5757);
  static const Color info = Color(0xFF00B4FF);

  // Overlay & Divider
  static const Color divider = Color(0x1AFFFFFF);
  static const Color overlay = Color(0x2F000000);

  // Compatibility aliases used by the modern screens.
  static const Color backgroundColor = background;
  static const Color primaryColor = primary;
  static const Color accentColor = accent;
  static const Color textDark = textPrimary;
  static const Color successColor = success;
  static const Color warningColor = warning;
  static const Color errorColor = error;
  static const Color dividerColor = divider;
  static const Color inputBorder = divider;

  // ===== Animation Durations =====
  static const Duration shortDuration = Duration(milliseconds: 200);
  static const Duration mediumDuration = Duration(milliseconds: 400);
  static const Duration longDuration = Duration(milliseconds: 600);

  // ===== Spacing =====
  static const double xs = 4.0;
  static const double sm = 8.0;
  static const double md = 16.0;
  static const double lg = 24.0;
  static const double xl = 32.0;
  static const double xxl = 48.0;

  // ===== Border Radius =====
  static const double radiusSm = 8.0;
  static const double radiusMd = 12.0;
  static const double radiusLg = 16.0;
  static const double radiusXl = 24.0;
  static const double radiusCircle = 50.0;

  // Compatibility aliases used by the modern screens.
  static const double borderRadius = radiusMd;
  static const double borderRadiusLarge = radiusLg;

  // ===== Shadows =====
  static final List<BoxShadow> shadowSm = [
    BoxShadow(
      color: Colors.black.withOpacity(0.1),
      blurRadius: 4,
      offset: const Offset(0, 2),
    ),
  ];

  static final List<BoxShadow> shadowMd = [
    BoxShadow(
      color: Colors.black.withOpacity(0.15),
      blurRadius: 12,
      offset: const Offset(0, 4),
    ),
  ];

  static final List<BoxShadow> shadowLg = [
    BoxShadow(
      color: Colors.black.withOpacity(0.2),
      blurRadius: 24,
      offset: const Offset(0, 8),
    ),
  ];

  static final List<BoxShadow> shadowGlow = [
    BoxShadow(
      color: primary.withOpacity(0.3),
      blurRadius: 16,
      offset: const Offset(0, 4),
    ),
  ];

  // ===== Build Theme Data =====
  static final ThemeData lightTheme = _buildLightTheme();
  static final ThemeData darkTheme = _buildDarkTheme();

  static ThemeData _buildLightTheme() {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      colorScheme: ColorScheme.light(
        primary: primary,
        secondary: secondary,
        tertiary: accent,
        surface: Color(0xFFF5F5F7),
        error: error,
      ),
      scaffoldBackgroundColor: Color(0xFFFBF8FF),
      appBarTheme: AppBarTheme(
        backgroundColor: Color(0xFFFBF8FF),
        elevation: 0,
        centerTitle: true,
        titleTextStyle: GoogleFonts.hankenGrotesk(
          fontSize: 20,
          fontWeight: FontWeight.w700,
          color: Color(0xFF0A0E27),
        ),
      ),
    );
  }

  static ThemeData _buildDarkTheme() {
    final baseTheme = ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: ColorScheme.dark(
        primary: primary,
        onPrimary: Colors.white,
        secondary: secondary,
        onSecondary: Colors.white,
        tertiary: accent,
        surface: surface,
        error: error,
        onError: Colors.white,
      ),
      scaffoldBackgroundColor: background,
    );

    // Text theme with enhanced typography
    final textTheme = GoogleFonts.interTextTheme(baseTheme.textTheme)
        .apply(bodyColor: textPrimary, displayColor: textPrimary)
        .copyWith(
          displayLarge: GoogleFonts.hankenGrotesk(
            fontSize: 36,
            fontWeight: FontWeight.w800,
            color: textPrimary,
            letterSpacing: -0.5,
          ),
          displayMedium: GoogleFonts.hankenGrotesk(
            fontSize: 32,
            fontWeight: FontWeight.w800,
            color: textPrimary,
            letterSpacing: -0.5,
          ),
          headlineLarge: GoogleFonts.hankenGrotesk(
            fontSize: 28,
            fontWeight: FontWeight.w700,
            color: textPrimary,
          ),
          headlineMedium: GoogleFonts.hankenGrotesk(
            fontSize: 24,
            fontWeight: FontWeight.w700,
            color: textPrimary,
          ),
          headlineSmall: GoogleFonts.hankenGrotesk(
            fontSize: 20,
            fontWeight: FontWeight.w700,
            color: textPrimary,
          ),
          titleLarge: GoogleFonts.inter(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: textPrimary,
          ),
          titleMedium: GoogleFonts.inter(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: textPrimary,
          ),
          titleSmall: GoogleFonts.inter(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: textSecondary,
          ),
          bodyLarge: GoogleFonts.inter(
            fontSize: 16,
            fontWeight: FontWeight.w500,
            color: textPrimary,
          ),
          bodyMedium: GoogleFonts.inter(
            fontSize: 14,
            fontWeight: FontWeight.w400,
            color: textPrimary,
          ),
          bodySmall: GoogleFonts.inter(
            fontSize: 12,
            fontWeight: FontWeight.w400,
            color: textMuted,
          ),
          labelLarge: GoogleFonts.inter(
            fontSize: 14,
            fontWeight: FontWeight.w700,
            color: textPrimary,
          ),
        );

    return baseTheme.copyWith(
      textTheme: textTheme,
      appBarTheme: AppBarTheme(
        backgroundColor: surface,
        elevation: 0,
        centerTitle: true,
        titleTextStyle: GoogleFonts.hankenGrotesk(
          fontSize: 22,
          fontWeight: FontWeight.w800,
          color: textPrimary,
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: primary,
          foregroundColor: Colors.white,
          padding: EdgeInsets.symmetric(
            horizontal: md,
            vertical: md,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(radiusMd),
          ),
          textStyle: GoogleFonts.inter(
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primaryDark,
          foregroundColor: Colors.white,
          elevation: 0,
          padding: EdgeInsets.symmetric(
            horizontal: md,
            vertical: md,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(radiusMd),
          ),
        ),
      ),
      cardTheme: CardTheme(
        color: surface,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radiusLg),
          side: BorderSide(
            color: divider,
            width: 1,
          ),
        ),
        margin: EdgeInsets.zero,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: surfaceLight,
        contentPadding: EdgeInsets.all(md),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusMd),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusMd),
          borderSide: BorderSide(color: divider, width: 1),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusMd),
          borderSide: BorderSide(color: primary, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusMd),
          borderSide: BorderSide(color: error, width: 1),
        ),
        labelStyle: TextStyle(color: textSecondary),
        hintStyle: TextStyle(color: textMuted),
      ),
    );
  }

  // ===== Gradient Helpers =====
  static LinearGradient get primaryGradient => LinearGradient(
    colors: [primary, primaryLight],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static LinearGradient get secondaryGradient => LinearGradient(
    colors: [secondary, secondaryLight],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static LinearGradient get accentGradient => LinearGradient(
    colors: [accent, accentGreen],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  // ===== Curve for animations =====
  static const Curve defaultCurve = Curves.easeInOutCubic;
  static const Curve bouncyCurve = Curves.elasticOut;
  static const Curve smoothCurve = Curves.easeInOutQuad;
}
