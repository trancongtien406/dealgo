import 'package:flutter/material.dart';

import '../tokens/dealgo_tokens.dart';

abstract final class DealGoTheme {
  static final ThemeData light = _light();

  static ThemeData _light() {
    const text = DealGoColors.text;
    const secondary = DealGoColors.textSecondary;
    final baseline = Typography.material2021().black.apply(
      bodyColor: text,
      displayColor: text,
    );

    TextStyle readable(
      TextStyle? source, {
      required double fontSize,
      required FontWeight fontWeight,
      Color color = text,
      double height = 1.4,
    }) {
      return (source ?? const TextStyle()).copyWith(
        fontSize: fontSize,
        fontWeight: fontWeight,
        color: color,
        height: height,
      );
    }

    final textTheme = baseline.copyWith(
      headlineMedium: readable(
        baseline.headlineMedium,
        fontSize: 24,
        fontWeight: FontWeight.w700,
        height: 1.35,
      ),
      titleLarge: readable(
        baseline.titleLarge,
        fontSize: 22,
        fontWeight: FontWeight.w700,
        height: 1.35,
      ),
      titleMedium: readable(
        baseline.titleMedium,
        fontSize: 18,
        fontWeight: FontWeight.w600,
        height: 1.35,
      ),
      bodyLarge: readable(
        baseline.bodyLarge,
        fontSize: 16,
        fontWeight: FontWeight.w400,
        height: 1.45,
      ),
      bodyMedium: readable(
        baseline.bodyMedium,
        fontSize: 15,
        fontWeight: FontWeight.w400,
        height: 1.45,
      ),
      bodySmall: readable(
        baseline.bodySmall,
        fontSize: 13,
        fontWeight: FontWeight.w400,
        color: secondary,
        height: 1.4,
      ),
      labelLarge: readable(
        baseline.labelLarge,
        fontSize: 16,
        fontWeight: FontWeight.w600,
        height: 1.25,
      ),
      labelSmall: readable(
        baseline.labelSmall,
        fontSize: 12,
        fontWeight: FontWeight.w500,
        color: secondary,
        height: 1.3,
      ),
    );

    final colorScheme = ColorScheme.fromSeed(
      seedColor: DealGoColors.primary,
      primary: DealGoColors.primary,
      onPrimary: Colors.white,
      surface: DealGoColors.canvas,
      onSurface: text,
      onSurfaceVariant: secondary,
      outline: DealGoColors.border,
      tertiary: DealGoColors.brandGreen,
      onTertiary: Colors.white,
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: DealGoColors.canvas,
      textTheme: textTheme,
      dividerColor: DealGoColors.border,
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: DealGoColors.card,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        shadowColor: Colors.transparent,
        indicatorColor: DealGoColors.subtlePurple,
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          final selected = states.contains(WidgetState.selected);
          return textTheme.labelSmall?.copyWith(
            color: selected ? DealGoColors.primary : secondary,
            fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
          );
        }),
        iconTheme: WidgetStateProperty.resolveWith((states) {
          final selected = states.contains(WidgetState.selected);
          return IconThemeData(
            color: selected ? DealGoColors.primary : secondary,
            size: 24,
          );
        }),
      ),
    );
  }
}
