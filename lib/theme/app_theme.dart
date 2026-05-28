import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppTheme {
  AppTheme._();

  // ── Core Colors ──
  static const Color black = Color(0xFF000000);
  static const Color white = Color(0xFFFFFFFF);
  static const Color purple = Color(0xFF7C3AED);
  static const Color cyan = Color(0xFF06B6D4);
  static const Color green = Color(0xFF22C55E);
  static const Color amber = Color(0xFFF59E0B);
  static const Color orange = Color(0xFFF97316);
  static const Color red = Color(0xFFEF4444);
  static const Color dimWhite = Color(0xFFAAAAAA);
  static const Color cardBg = Color(0xFF0A0A0A);
  static const Color surfaceDark = Color(0xFF111111);

  // ── Neon Glow Decorations ──
  static BoxDecoration neonGlow({
    Color color = purple,
    double blurRadius = 20,
    double spreadRadius = 2,
    double borderRadius = 16,
  }) {
    return BoxDecoration(
      color: cardBg,
      borderRadius: BorderRadius.circular(borderRadius),
      border: Border.all(color: color.withValues(alpha: 0.3), width: 1),
      boxShadow: [
        BoxShadow(
          color: color.withValues(alpha: 0.6),
          blurRadius: blurRadius,
          spreadRadius: spreadRadius,
        ),
      ],
    );
  }

  static BoxDecoration neonBorder({
    Color color = purple,
    double borderRadius = 16,
    double borderWidth = 1.5,
  }) {
    return BoxDecoration(
      color: black,
      borderRadius: BorderRadius.circular(borderRadius),
      border: Border.all(color: color.withValues(alpha: 0.5), width: borderWidth),
      boxShadow: [
        BoxShadow(
          color: color.withValues(alpha: 0.3),
          blurRadius: 12,
          spreadRadius: 0,
        ),
      ],
    );
  }

  static BoxDecoration neonLeftBorder({Color color = purple}) {
    return BoxDecoration(
      color: cardBg,
      borderRadius: BorderRadius.circular(12),
      border: Border(
        left: BorderSide(color: color, width: 3),
      ),
      boxShadow: [
        BoxShadow(
          color: color.withValues(alpha: 0.2),
          blurRadius: 8,
          spreadRadius: 0,
        ),
      ],
    );
  }

  // ── Text Styles ──
  static TextStyle get headingXL => GoogleFonts.inter(
        fontSize: 48,
        fontWeight: FontWeight.w900,
        color: white,
        letterSpacing: 4,
      );

  static TextStyle get headingLarge => GoogleFonts.inter(
        fontSize: 32,
        fontWeight: FontWeight.w800,
        color: white,
        letterSpacing: 2,
      );

  static TextStyle get headingMedium => GoogleFonts.inter(
        fontSize: 24,
        fontWeight: FontWeight.w700,
        color: white,
      );

  static TextStyle get headingSmall => GoogleFonts.inter(
        fontSize: 18,
        fontWeight: FontWeight.w600,
        color: white,
      );

  static TextStyle get bodyLarge => GoogleFonts.inter(
        fontSize: 16,
        fontWeight: FontWeight.w400,
        color: white,
      );

  static TextStyle get bodyMedium => GoogleFonts.inter(
        fontSize: 14,
        fontWeight: FontWeight.w400,
        color: dimWhite,
      );

  static TextStyle get bodySmall => GoogleFonts.inter(
        fontSize: 12,
        fontWeight: FontWeight.w400,
        color: dimWhite,
      );

  static TextStyle get timerDisplay => GoogleFonts.inter(
        fontSize: 72,
        fontWeight: FontWeight.w900,
        color: white,
        letterSpacing: 2,
      );

  static TextStyle get countdownDisplay => GoogleFonts.inter(
        fontSize: 120,
        fontWeight: FontWeight.w900,
        color: purple,
      );

  static TextStyle get labelStyle => GoogleFonts.inter(
        fontSize: 13,
        fontWeight: FontWeight.w500,
        color: dimWhite,
        letterSpacing: 1.5,
      );

  // ── Theme Data ──
  static ThemeData get darkTheme {
    return ThemeData(
      brightness: Brightness.dark,
      scaffoldBackgroundColor: black,
      primaryColor: purple,
      colorScheme: const ColorScheme.dark(
        primary: purple,
        secondary: cyan,
        surface: black,
        onPrimary: white,
        onSecondary: white,
        onSurface: white,
      ),
      textTheme: GoogleFonts.interTextTheme(ThemeData.dark().textTheme),
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      pageTransitionsTheme: const PageTransitionsTheme(
        builders: {
          TargetPlatform.android: FadeUpwardsPageTransitionsBuilder(),
          TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
        },
      ),
    );
  }

  // ── Page Route with Fade ──
  static Route<T> fadeRoute<T>(Widget page, {int durationMs = 300}) {
    return PageRouteBuilder<T>(
      pageBuilder: (context, animation, secondaryAnimation) => page,
      transitionDuration: Duration(milliseconds: durationMs),
      reverseTransitionDuration: Duration(milliseconds: durationMs),
      transitionsBuilder: (context, animation, secondaryAnimation, child) {
        return FadeTransition(
          opacity: CurvedAnimation(
            parent: animation,
            curve: Curves.easeInOut,
          ),
          child: child,
        );
      },
    );
  }
}
