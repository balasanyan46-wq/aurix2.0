import 'package:flutter/material.dart';

/// Premium futuristic orange palette — тёмный фон, оранжевые акценты
class DesignTheme {
  DesignTheme._();

  static const Color primaryOrange = Color(0xFFFF6B35);
  static const Color accentAmber = Color(0xFFFFB347);
  static const Color neonOrange = Color(0xFFFF8C42);
  static const Color deepOrange = Color(0xFFE85D04);
  static const Color darkBg = Color(0xFF0D0D0F);
  static const Color surfaceDark = Color(0xFF161619);
  static const Color surfaceCard = Color(0x1AFFFFFF);
  static const Color textPrimary = Color(0xFFFFFFFF);
  static const Color textSecondary = Color(0xFFB0B0B5);
  static const Color borderSubtle = Color(0x33FFFFFF);

  static ThemeData get theme => ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        scaffoldBackgroundColor: darkBg,
        colorScheme: ColorScheme.dark(
          primary: primaryOrange,
          secondary: accentAmber,
          surface: surfaceDark,
          error: const Color(0xFFE53935),
          onPrimary: Colors.black,
          onSecondary: Colors.black,
          onSurface: textPrimary,
          onError: Colors.white,
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.transparent,
          elevation: 0,
          centerTitle: true,
          foregroundColor: textPrimary,
          titleTextStyle: TextStyle(
            color: textPrimary,
            fontSize: 20,
            fontWeight: FontWeight.w700,
            letterSpacing: 2,
          ),
        ),
        textTheme: const TextTheme(
          displayLarge: TextStyle(color: textPrimary, fontSize: 48, fontWeight: FontWeight.w800, letterSpacing: -1),
          displayMedium: TextStyle(color: textPrimary, fontSize: 36, fontWeight: FontWeight.w700),
          headlineLarge: TextStyle(color: textPrimary, fontSize: 28, fontWeight: FontWeight.w700),
          headlineMedium: TextStyle(color: textPrimary, fontSize: 24, fontWeight: FontWeight.w600),
          titleLarge: TextStyle(color: textPrimary, fontSize: 20, fontWeight: FontWeight.w600),
          bodyLarge: TextStyle(color: textPrimary, fontSize: 16, height: 1.5),
          bodyMedium: TextStyle(color: textSecondary, fontSize: 14, height: 1.5),
          labelLarge: TextStyle(color: textPrimary, fontSize: 14, fontWeight: FontWeight.w600),
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: surfaceCard,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
          enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: borderSubtle)),
          focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: primaryOrange, width: 2)),
          contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
          hintStyle: const TextStyle(color: textSecondary),
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: primaryOrange,
            foregroundColor: Colors.black,
            elevation: 0,
            padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 18),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          ),
        ),
      );
}
