import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../motion/dealgo_page_transitions.dart';
import '../tokens/dealgo_tokens.dart';

abstract final class DealGoTheme {
  static final ThemeData light = _build(DealGoPalette.light);
  static final ThemeData dark = _build(DealGoPalette.dark);

  /// Status bar for our light canvas: dark icons (time, battery) on a
  /// transparent bar. iOS otherwise follows the device appearance and shows
  /// white icons in Dark Mode, which vanish on light screens.
  static const SystemUiOverlayStyle lightCanvasOverlay = SystemUiOverlayStyle(
    statusBarColor: Color(0x00000000),
    statusBarIconBrightness: Brightness.dark, // Android
    statusBarBrightness: Brightness.light, // iOS: light bg -> dark icons
  );

  /// Status bar over dark / brand-colored headers: light icons.
  static const SystemUiOverlayStyle darkHeaderOverlay = SystemUiOverlayStyle(
    statusBarColor: Color(0x00000000),
    statusBarIconBrightness: Brightness.light,
    statusBarBrightness: Brightness.dark,
  );

  static ThemeData _build(DealGoPalette colors) {
    final text = colors.text;
    final secondary = colors.textSecondary;
    final dark = colors == DealGoPalette.dark;
    final baseline = Typography.material2021().black.apply(
      bodyColor: text,
      displayColor: text,
      fontFamily: DealGoTypography.fontFamily,
    );

    TextStyle readable(
      TextStyle? source, {
      required double fontSize,
      required FontWeight fontWeight,
      Color? color,
      double height = 1.4,
      double letterSpacing = 0,
    }) {
      return (source ?? const TextStyle()).copyWith(
        fontSize: fontSize,
        fontWeight: fontWeight,
        color: color ?? text,
        height: height,
        letterSpacing: letterSpacing,
      );
    }

    // Scale tuned to the mockups: very heavy display/headline, calm body.
    final textTheme = baseline.copyWith(
      displaySmall: readable(
        baseline.displaySmall,
        fontSize: 30,
        fontWeight: FontWeight.w800,
        height: 1.2,
        letterSpacing: -0.4,
      ),
      headlineLarge: readable(
        baseline.headlineLarge,
        fontSize: 28,
        fontWeight: FontWeight.w800,
        height: 1.25,
        letterSpacing: -0.3,
      ),
      headlineMedium: readable(
        baseline.headlineMedium,
        fontSize: 24,
        fontWeight: FontWeight.w800,
        height: 1.3,
        letterSpacing: -0.2,
      ),
      headlineSmall: readable(
        baseline.headlineSmall,
        fontSize: 20,
        fontWeight: FontWeight.w700,
        height: 1.3,
      ),
      titleLarge: readable(
        baseline.titleLarge,
        fontSize: 20,
        fontWeight: FontWeight.w700,
        height: 1.35,
      ),
      titleMedium: readable(
        baseline.titleMedium,
        fontSize: 17,
        fontWeight: FontWeight.w700,
        height: 1.35,
      ),
      titleSmall: readable(
        baseline.titleSmall,
        fontSize: 15,
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
        fontSize: 14.5,
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
      labelMedium: readable(
        baseline.labelMedium,
        fontSize: 13,
        fontWeight: FontWeight.w600,
        height: 1.3,
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
      primaryContainer: colors.subtlePurple,
      onPrimaryContainer: colors.onPrimaryContainer,
      surface: colors.canvas,
      onSurface: text,
      onSurfaceVariant: secondary,
      surfaceContainerLowest: colors.card,
      outline: colors.border,
      outlineVariant: colors.divider,
      tertiary: DealGoColors.brandGreen,
      onTertiary: Colors.white,
      error: DealGoColors.danger,
      errorContainer: colors.dangerSurface,
    );

    OutlineInputBorder inputBorder(Color color, [double width = 1]) {
      return OutlineInputBorder(
        borderRadius: BorderRadius.circular(DealGoRadius.input),
        borderSide: BorderSide(color: color, width: width),
      );
    }

    return ThemeData(
      useMaterial3: true,
      fontFamily: DealGoTypography.fontFamily,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: colors.canvas,
      textTheme: textTheme,
      dividerColor: colors.border,
      splashFactory: InkRipple.splashFactory,
      materialTapTargetSize: MaterialTapTargetSize.padded,
      visualDensity: VisualDensity.standard,
      pageTransitionsTheme: DealGoPageTransitions.theme,
      iconTheme: IconThemeData(color: text, size: 22),
      dividerTheme: DividerThemeData(
        color: colors.divider,
        thickness: 1,
        space: 1,
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: colors.canvas,
        foregroundColor: text,
        elevation: 0,
        scrolledUnderElevation: 0,
        surfaceTintColor: Colors.transparent,
        centerTitle: true,
        titleTextStyle: textTheme.titleMedium,
        iconTheme: IconThemeData(color: text, size: 22),
        systemOverlayStyle: dark
            ? DealGoTheme.darkHeaderOverlay
            : DealGoTheme.lightCanvasOverlay,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: colors.card,
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: DealGoSpacing.s16,
          vertical: DealGoSpacing.s14,
        ),
        hintStyle: textTheme.bodyLarge?.copyWith(color: colors.textTertiary),
        labelStyle: textTheme.bodyMedium?.copyWith(color: secondary),
        floatingLabelStyle: textTheme.labelMedium?.copyWith(
          color: DealGoColors.primary,
        ),
        helperStyle: textTheme.bodySmall,
        errorStyle: textTheme.bodySmall?.copyWith(color: DealGoColors.danger),
        prefixIconColor: secondary,
        suffixIconColor: secondary,
        border: inputBorder(colors.border),
        enabledBorder: inputBorder(colors.border),
        disabledBorder: inputBorder(colors.divider),
        focusedBorder: inputBorder(DealGoColors.primary, 1.6),
        errorBorder: inputBorder(DealGoColors.danger),
        focusedErrorBorder: inputBorder(DealGoColors.danger, 1.6),
      ),
      // Buttons never get a fixed height: a min height for the tap target plus
      // balanced padding, so a wrapped 2-line label grows evenly.
      filledButtonTheme: FilledButtonThemeData(style: _ctaStyle(textTheme)),
      elevatedButtonTheme: ElevatedButtonThemeData(style: _ctaStyle(textTheme)),
      outlinedButtonTheme: OutlinedButtonThemeData(style: _ctaStyle(textTheme)),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: DealGoColors.primary,
          padding: const EdgeInsets.symmetric(
            horizontal: DealGoSpacing.s12,
            vertical: DealGoSpacing.s8,
          ),
          minimumSize: const Size(
            DealGoDimensions.minTapTarget,
            DealGoDimensions.minTapTarget,
          ),
          textStyle: textTheme.labelMedium?.copyWith(fontSize: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(DealGoRadius.input),
          ),
        ),
      ),
      iconButtonTheme: IconButtonThemeData(
        style: IconButton.styleFrom(
          foregroundColor: text,
          minimumSize: const Size(
            DealGoDimensions.minTapTarget,
            DealGoDimensions.minTapTarget,
          ),
        ),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: colors.card,
        selectedColor: colors.subtlePurple,
        side: BorderSide(color: colors.border),
        labelStyle: textTheme.labelMedium,
        shape: const StadiumBorder(),
        showCheckmark: false,
      ),
      checkboxTheme: CheckboxThemeData(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
        side: BorderSide(color: colors.border, width: 1.5),
        fillColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected)
              ? DealGoColors.primary
              : colors.card,
        ),
      ),
      radioTheme: RadioThemeData(
        fillColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected)
              ? DealGoColors.primary
              : colors.border,
        ),
      ),
      switchTheme: SwitchThemeData(
        thumbColor: const WidgetStatePropertyAll(Colors.white),
        trackOutlineColor: const WidgetStatePropertyAll(Colors.transparent),
        trackColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected)
              ? DealGoColors.primary
              : colors.border,
        ),
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: DealGoColors.primary,
        linearTrackColor: colors.subtlePurple,
        circularTrackColor: Colors.transparent,
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: colors.card,
        surfaceTintColor: Colors.transparent,
        showDragHandle: false,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(
            top: Radius.circular(DealGoRadius.sheet),
          ),
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: colors.card,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(DealGoRadius.card),
        ),
        titleTextStyle: textTheme.titleMedium,
        contentTextStyle: textTheme.bodyMedium,
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: dark
            ? const Color(0xFFF4F1FA)
            : const Color(0xFF171B2C),
        contentTextStyle: textTheme.bodyMedium?.copyWith(
          color: dark ? const Color(0xFF171B2C) : Colors.white,
        ),
        actionTextColor: DealGoColors.primaryLight,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(DealGoRadius.input),
        ),
      ),
      tooltipTheme: TooltipThemeData(
        decoration: BoxDecoration(
          color: dark ? const Color(0xFFF4F1FA) : const Color(0xFF171B2C),
          borderRadius: BorderRadius.circular(DealGoRadius.small),
        ),
        textStyle: textTheme.labelSmall?.copyWith(
          color: dark ? const Color(0xFF171B2C) : Colors.white,
        ),
      ),
      listTileTheme: ListTileThemeData(
        iconColor: DealGoColors.primary,
        titleTextStyle: textTheme.titleSmall,
        subtitleTextStyle: textTheme.bodySmall,
        minVerticalPadding: DealGoSpacing.s12,
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: colors.card,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        shadowColor: Colors.transparent,
        indicatorColor: colors.subtlePurple,
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

ButtonStyle _ctaStyle(TextTheme textTheme) => ButtonStyle(
  minimumSize: const WidgetStatePropertyAll(
    Size(DealGoDimensions.minTapTarget, DealGoDimensions.minTapTarget),
  ),
  padding: const WidgetStatePropertyAll(
    EdgeInsets.symmetric(
      horizontal: DealGoSpacing.s16,
      vertical: DealGoSpacing.s12,
    ),
  ),
  shape: WidgetStatePropertyAll(
    RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(DealGoRadius.button),
    ),
  ),
);
