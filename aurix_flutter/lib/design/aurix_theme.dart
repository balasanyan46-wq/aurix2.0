import 'package:flutter/material.dart';

/// AURIX V2 — Музыкальный Bloomberg. Premium neutral, data-first.
/// Строгая иерархия, один акцент, никакого glow.
class AurixTokens {
  AurixTokens._();

  // Surfaces — премиальная нейтральность
  static const Color bg0 = Color(0xFF08080A);
  static const Color bg1 = Color(0xFF0C0C0F);
  static const Color bg2 = Color(0xFF12121A);

  // Borders — чёткие границы
  static const Color border = Color(0xFF1E1E24);
  static const Color borderLight = Color(0xFF2A2A32);

  // Text hierarchy
  static const Color text = Color(0xFFFAFAFA);
  static const Color textSecondary = Color(0xFFB8B8BE);
  static const Color muted = Color(0xFF6B6B73);

  // Accent — старые цвета
  static const Color accent = Color(0xFFFF6B35);
  static const Color accentMuted = Color(0xFFE85D04);

  // Semantic
  static const Color positive = Color(0xFF22C55E);
  static const Color negative = Color(0xFF6B7280);

  // Legacy aliases
  static const Color orange = Color(0xFFFF6B35);
  static const Color orange2 = Color(0xFFE85D04);
  static Color get orangeGlow => orange.withValues(alpha: 0.5);

  static Color stroke([double opacity = 0.12]) =>
      Color.fromRGBO(30, 30, 36, opacity.clamp(0.0, 1.0));

  static Color glass([double opacity = 0.04]) =>
      Color.fromRGBO(255, 255, 255, opacity.clamp(0.0, 1.0));

  /// Tabular figures для чисел
  static const List<FontFeature> tabularFigures = [FontFeature.tabularFigures()];
}

ThemeData aurixDarkTheme() {
  return ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    scaffoldBackgroundColor: AurixTokens.bg0,
    colorScheme: ColorScheme.dark(
      primary: AurixTokens.accent,
      secondary: AurixTokens.accentMuted,
      surface: AurixTokens.bg1,
      error: const Color(0xFFDC2626),
      onPrimary: Colors.black,
      onSecondary: Colors.black,
      onSurface: AurixTokens.text,
      onError: Colors.white,
    ),
    textTheme: TextTheme(
      displayLarge: TextStyle(
        color: AurixTokens.text,
        fontSize: 72,
        fontWeight: FontWeight.w800,
        letterSpacing: -2,
        fontFeatures: AurixTokens.tabularFigures,
      ),
      displayMedium: TextStyle(
        color: AurixTokens.text,
        fontSize: 48,
        fontWeight: FontWeight.w800,
        letterSpacing: -1,
        fontFeatures: AurixTokens.tabularFigures,
      ),
      headlineLarge: TextStyle(
        color: AurixTokens.text,
        fontSize: 32,
        fontWeight: FontWeight.w700,
        letterSpacing: -0.5,
      ),
      headlineMedium: TextStyle(
        color: AurixTokens.text,
        fontSize: 24,
        fontWeight: FontWeight.w600,
      ),
      titleLarge: TextStyle(
        color: AurixTokens.text,
        fontSize: 18,
        fontWeight: FontWeight.w600,
      ),
      titleMedium: TextStyle(
        color: AurixTokens.text,
        fontSize: 16,
        fontWeight: FontWeight.w600,
      ),
      bodyLarge: TextStyle(
        color: AurixTokens.text,
        fontSize: 16,
        height: 1.5,
      ),
      bodyMedium: TextStyle(
        color: AurixTokens.muted,
        fontSize: 14,
        height: 1.5,
      ),
      labelLarge: TextStyle(
        color: AurixTokens.text,
        fontSize: 14,
        fontWeight: FontWeight.w600,
      ),
    ),
  );
}
