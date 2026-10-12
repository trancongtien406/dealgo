import 'package:flutter/material.dart';

/// Proposed design baseline extracted from DealGo static mockups.
/// Review against visual references before marking this production-ready.
abstract final class DealGoColors {
  static const purple = Color(0xFF6D28D9);
  static const purplePressed = Color(0xFF5820B5);
  static const purpleTint = Color(0xFFF2EAFF);
  static const green = Color(0xFF16A34A);
  static const greenTint = Color(0xFFE7F8EE);
  static const warning = Color(0xFFCA7A17);
  static const error = Color(0xFFD63354);
  static const info = Color(0xFF2463C8);
  static const canvas = Color(0xFFFBFAFD);
  static const subtle = Color(0xFFF6F3FA);
  static const textPrimary = Color(0xFF171B2C);
  static const textSecondary = Color(0xFF666B80);
  static const border = Color(0xFFE7E3EF);
}

abstract final class DealGoSpacing {
  static const xxs = 4.0;
  static const xs = 8.0;
  static const sm = 12.0;
  static const md = 16.0;
  static const lg = 20.0;
  static const xl = 24.0;
  static const xxl = 32.0;
}

abstract final class DealGoRadius {
  static const input = 12.0;
  static const button = 16.0;
  static const card = 20.0;
}

ThemeData buildDealGoLightTheme() {
  final scheme = ColorScheme.fromSeed(
    seedColor: DealGoColors.purple,
    brightness: Brightness.light,
  ).copyWith(
    primary: DealGoColors.purple,
    onPrimary: Colors.white,
    secondary: DealGoColors.green,
    onSecondary: Colors.white,
    surface: Colors.white,
    onSurface: DealGoColors.textPrimary,
    error: DealGoColors.error,
  );

  return ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    scaffoldBackgroundColor: DealGoColors.canvas,
    textTheme: const TextTheme(
      headlineMedium: TextStyle(
        fontSize: 28, height: 34 / 28, fontWeight: FontWeight.w800,
        color: DealGoColors.textPrimary,
      ),
      headlineSmall: TextStyle(
        fontSize: 22, height: 28 / 22, fontWeight: FontWeight.w700,
        color: DealGoColors.textPrimary,
      ),
      titleLarge: TextStyle(
        fontSize: 18, height: 24 / 18, fontWeight: FontWeight.w700,
        color: DealGoColors.textPrimary,
      ),
      titleMedium: TextStyle(
        fontSize: 16, height: 22 / 16, fontWeight: FontWeight.w700,
        color: DealGoColors.textPrimary,
      ),
      bodyLarge: TextStyle(
        fontSize: 16, height: 24 / 16,
        color: DealGoColors.textPrimary,
      ),
      bodyMedium: TextStyle(
        fontSize: 15, height: 22 / 15,
        color: DealGoColors.textPrimary,
      ),
      bodySmall: TextStyle(
        fontSize: 13, height: 19 / 13,
        color: DealGoColors.textSecondary,
      ),
      labelLarge: TextStyle(
        fontSize: 16, height: 22 / 16, fontWeight: FontWeight.w700,
      ),
      labelSmall: TextStyle(
        fontSize: 12, height: 17 / 12,
        color: DealGoColors.textSecondary,
      ),
    ),
    appBarTheme: const AppBarTheme(
      backgroundColor: DealGoColors.canvas,
      foregroundColor: DealGoColors.textPrimary,
      centerTitle: false,
      elevation: 0,
      surfaceTintColor: Colors.transparent,
    ),
    cardTheme: CardThemeData(
      color: Colors.white,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(DealGoRadius.card),
        side: const BorderSide(color: DealGoColors.border),
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: DealGoColors.purple,
        foregroundColor: Colors.white,
        minimumSize: const Size(48, 52),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(DealGoRadius.button),
        ),
        textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: Colors.white,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(DealGoRadius.input),
        borderSide: const BorderSide(color: DealGoColors.border),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(DealGoRadius.input),
        borderSide: const BorderSide(color: DealGoColors.border),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(DealGoRadius.input),
        borderSide: const BorderSide(color: DealGoColors.purple, width: 1.5),
      ),
    ),
  );
}
