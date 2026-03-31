import 'package:flutter/material.dart';

/// AURIX premium dark visual system — Artist Control System.
class AurixTokens {
  AurixTokens._();

  // ─── Foundations ───
  static const Color bg0 = Color(0xFF08080C);
  static const Color bg1 = Color(0xFF111118);
  static const Color bg2 = Color(0xFF1A1A26);
  static const Color bgElevated = Color(0xFF222233);

  // Extended surface palette for cards and panels.
  static const Color surface1 = Color(0xFF131620);
  static const Color surface2 = Color(0xFF161A28);
  static const Color surface3 = Color(0xFF1C2234);

  static const Color border = Color(0xFF2A2A40);
  static const Color borderLight = Color(0xFF363654);
  static const Color borderStrong = Color(0xFF4A4A6A);

  // ─── Typography colors ───
  static const Color text = Color(0xFFF2F5FF);
  static const Color textSecondary = Color(0xFFC4CFDE);
  static const Color muted = Color(0xFF8A96AE);
  static const Color micro = Color(0xFF6B7A94);

  // ─── Accent palette — orange primary ───
  static const Color accent = Color(0xFFFF6A1A);
  static const Color accentMuted = Color(0xFFE05A10);
  static const Color accentWarm = Color(0xFFFF8B4D);
  static const Color accentGlow = Color(0xFFFF7B33);
  static const Color accentSoft = Color(0xFFFF9D66);

  // ─── AI accent — purple ───
  static const Color aiAccent = Color(0xFF7B5CFF);
  static const Color aiGlow = Color(0xFF9B7FFF);
  static const Color aiSoft = Color(0xFFB8A3FF);
  static const Color coolUndertone = Color(0xFF3E4F8C);

  // ─── Semantics ───
  static const Color positive = Color(0xFF4DB88C);
  static const Color positiveGlow = Color(0xFF5FCFA0);
  static const Color warning = Color(0xFFD2A45A);
  static const Color warningGlow = Color(0xFFE0B86A);
  static const Color danger = Color(0xFFC97171);
  static const Color negative = Color(0xFF7A8496);

  // ─── Legacy aliases ───
  static const Color orange = accent;
  static const Color orange2 = accentMuted;
  static Color get orangeGlow => accentGlow.withValues(alpha: 0.34);

  // ─── Font families ───
  static const String fontDisplay = 'Unbounded';
  static const String fontHeading = 'Unbounded';
  static const String fontBody = 'Manrope';
  static const String fontMono = 'SpaceGrotesk';

  // ─── Spacing scale ───
  static const double s2 = 2;
  static const double s4 = 4;
  static const double s6 = 6;
  static const double s8 = 8;
  static const double s10 = 10;
  static const double s12 = 12;
  static const double s16 = 16;
  static const double s20 = 20;
  static const double s24 = 24;
  static const double s32 = 32;
  static const double s40 = 40;
  static const double s48 = 48;
  static const double s56 = 56;
  static const double s64 = 64;

  // ─── Radius system ───
  static const double radiusXs = 8;
  static const double radiusSm = 12;
  static const double radiusField = 14;
  static const double radiusChip = 16;
  static const double radiusButton = 18;
  static const double radiusCard = 20;
  static const double radiusHero = 28;
  static const double radiusXl = 32;

  // ─── Durations ───
  static const Duration dFast = Duration(milliseconds: 140);
  static const Duration dMedium = Duration(milliseconds: 240);
  static const Duration dSlow = Duration(milliseconds: 400);
  static const Duration dEntrance = Duration(milliseconds: 500);

  // ─── Curves ───
  static const Curve cEase = Curves.easeOutCubic;
  static const Curve cBounce = Curves.easeOutBack;
  static const Curve cSnap = Curves.easeInOutCubicEmphasized;

  static Color stroke([double opacity = 0.12]) =>
      Color.fromRGBO(122, 143, 178, opacity.clamp(0.0, 1.0));

  static Color glass([double opacity = 0.04]) =>
      Color.fromRGBO(255, 255, 255, opacity.clamp(0.0, 1.0));

  static List<BoxShadow> get subtleShadow => [
        BoxShadow(
          color: Colors.black.withValues(alpha: 0.24),
          blurRadius: 24,
          spreadRadius: -16,
          offset: const Offset(0, 12),
        ),
      ];

  static List<BoxShadow> get elevatedShadow => [
        BoxShadow(
          color: Colors.black.withValues(alpha: 0.32),
          blurRadius: 42,
          spreadRadius: -18,
          offset: const Offset(0, 20),
        ),
      ];

  static List<BoxShadow> get accentGlowShadow => [
        BoxShadow(
          color: accentGlow.withValues(alpha: 0.22),
          blurRadius: 36,
          spreadRadius: -14,
          offset: const Offset(0, 12),
        ),
      ];

  static List<BoxShadow> get aiGlowShadow => [
        BoxShadow(
          color: aiAccent.withValues(alpha: 0.18),
          blurRadius: 32,
          spreadRadius: -12,
          offset: const Offset(0, 10),
        ),
      ];

  /// Tabular figures for numbers
  static const List<FontFeature> tabularFigures = [FontFeature.tabularFigures()];

  /// Card gradient (top-left → bottom-right)
  static LinearGradient get cardGradient => LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          bg1.withValues(alpha: 0.97),
          bg2.withValues(alpha: 0.92),
        ],
      );

  /// Elevated card gradient (slightly lighter)
  static LinearGradient get cardGradientElevated => LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          bgElevated.withValues(alpha: 0.6),
          bg1.withValues(alpha: 0.95),
        ],
      );
}

ThemeData aurixDarkTheme() {
  return ThemeData(
    useMaterial3: true,
    fontFamily: AurixTokens.fontBody,
    brightness: Brightness.dark,
    scaffoldBackgroundColor: AurixTokens.bg0,
    colorScheme: ColorScheme.dark(
      primary: AurixTokens.accent,
      secondary: AurixTokens.aiAccent,
      surface: AurixTokens.bg1,
      error: AurixTokens.danger,
      onPrimary: Colors.white,
      onSecondary: Colors.white,
      onSurface: AurixTokens.text,
      onError: Colors.white,
    ),
    dividerColor: AurixTokens.stroke(0.16),
    textTheme: TextTheme(
      displayLarge: TextStyle(
        fontFamily: AurixTokens.fontDisplay,
        color: AurixTokens.text,
        fontSize: 56,
        fontWeight: FontWeight.w800,
        letterSpacing: -1.5,
        height: 1.05,
        fontFeatures: AurixTokens.tabularFigures,
      ),
      displayMedium: TextStyle(
        fontFamily: AurixTokens.fontDisplay,
        color: AurixTokens.text,
        fontSize: 40,
        fontWeight: FontWeight.w700,
        letterSpacing: -1,
        height: 1.1,
        fontFeatures: AurixTokens.tabularFigures,
      ),
      headlineLarge: TextStyle(
        fontFamily: AurixTokens.fontHeading,
        color: AurixTokens.text,
        fontSize: 28,
        fontWeight: FontWeight.w700,
        letterSpacing: -0.4,
        height: 1.14,
      ),
      headlineMedium: TextStyle(
        fontFamily: AurixTokens.fontHeading,
        color: AurixTokens.text,
        fontSize: 22,
        fontWeight: FontWeight.w600,
        letterSpacing: -0.2,
        height: 1.2,
      ),
      titleLarge: TextStyle(
        fontFamily: AurixTokens.fontBody,
        color: AurixTokens.text,
        fontSize: 20,
        fontWeight: FontWeight.w700,
        height: 1.24,
      ),
      titleMedium: TextStyle(
        fontFamily: AurixTokens.fontBody,
        color: AurixTokens.text,
        fontSize: 17,
        fontWeight: FontWeight.w600,
        height: 1.25,
      ),
      bodyLarge: TextStyle(
        fontFamily: AurixTokens.fontBody,
        color: AurixTokens.text,
        fontSize: 16,
        height: 1.62,
      ),
      bodyMedium: TextStyle(
        fontFamily: AurixTokens.fontBody,
        color: AurixTokens.muted,
        fontSize: 14,
        height: 1.58,
      ),
      bodySmall: TextStyle(
        fontFamily: AurixTokens.fontBody,
        color: AurixTokens.textSecondary,
        fontSize: 12.5,
        height: 1.5,
      ),
      labelLarge: TextStyle(
        fontFamily: AurixTokens.fontBody,
        color: AurixTokens.text,
        fontSize: 14.5,
        fontWeight: FontWeight.w700,
      ),
      labelMedium: TextStyle(
        fontFamily: AurixTokens.fontBody,
        color: AurixTokens.textSecondary,
        fontSize: 12.5,
        fontWeight: FontWeight.w600,
      ),
      labelSmall: TextStyle(
        fontFamily: AurixTokens.fontBody,
        color: AurixTokens.micro,
        fontSize: 11,
        fontWeight: FontWeight.w600,
        letterSpacing: 0.42,
      ),
    ),
    appBarTheme: AppBarTheme(
      backgroundColor: AurixTokens.bg1.withValues(alpha: 0.8),
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      scrolledUnderElevation: 0,
      foregroundColor: AurixTokens.text,
      titleTextStyle: TextStyle(
        fontFamily: AurixTokens.fontHeading,
        color: AurixTokens.text,
        fontSize: 16,
        fontWeight: FontWeight.w700,
      ),
    ),
    cardTheme: CardThemeData(
      color: AurixTokens.bg1,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AurixTokens.radiusCard),
        side: BorderSide(color: AurixTokens.stroke(0.22)),
      ),
      margin: EdgeInsets.zero,
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: AurixTokens.surface1.withValues(alpha: 0.6),
      labelStyle: TextStyle(
        fontFamily: AurixTokens.fontBody,
        color: AurixTokens.muted,
        fontSize: 13,
      ),
      hintStyle: TextStyle(
        fontFamily: AurixTokens.fontBody,
        color: AurixTokens.muted.withValues(alpha: 0.6),
        fontSize: 13,
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AurixTokens.radiusField),
        borderSide: BorderSide(color: AurixTokens.stroke(0.18)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AurixTokens.radiusField),
        borderSide: BorderSide(color: AurixTokens.stroke(0.18)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AurixTokens.radiusField),
        borderSide: BorderSide(color: AurixTokens.accent.withValues(alpha: 0.65), width: 1.5),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AurixTokens.radiusField),
        borderSide: BorderSide(color: AurixTokens.danger.withValues(alpha: 0.5)),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AurixTokens.radiusField),
        borderSide: BorderSide(color: AurixTokens.danger.withValues(alpha: 0.7), width: 1.5),
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: AurixTokens.accent,
        foregroundColor: Colors.white,
        disabledBackgroundColor: AurixTokens.bg2,
        disabledForegroundColor: AurixTokens.muted,
        textStyle: TextStyle(
          fontFamily: AurixTokens.fontBody,
          fontWeight: FontWeight.w700,
          fontSize: 14,
        ),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AurixTokens.radiusButton),
        ),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: AurixTokens.text,
        side: BorderSide(color: AurixTokens.stroke(0.28)),
        textStyle: TextStyle(
          fontFamily: AurixTokens.fontBody,
          fontWeight: FontWeight.w600,
          fontSize: 13,
        ),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AurixTokens.radiusButton),
        ),
      ),
    ),
    chipTheme: ChipThemeData(
      backgroundColor: AurixTokens.bg2.withValues(alpha: 0.9),
      selectedColor: AurixTokens.accent.withValues(alpha: 0.22),
      disabledColor: AurixTokens.bg2.withValues(alpha: 0.5),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      side: BorderSide(color: AurixTokens.stroke(0.22)),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AurixTokens.radiusChip),
      ),
      labelStyle: TextStyle(
        fontFamily: AurixTokens.fontBody,
        color: AurixTokens.textSecondary,
        fontSize: 12,
        fontWeight: FontWeight.w600,
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: AurixTokens.textSecondary,
        textStyle: TextStyle(
          fontFamily: AurixTokens.fontBody,
          fontWeight: FontWeight.w600,
          fontSize: 13,
        ),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      ),
    ),
  );
}
