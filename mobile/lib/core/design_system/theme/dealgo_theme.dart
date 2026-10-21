import 'package:flutter/material.dart';

import '../../motion/dealgo_page_transitions.dart';
import '../tokens/dealgo_tokens.dart';

abstract final class DealGoTheme {
  static final ThemeData light = _light();

  static ThemeData _light() {
    const text = DealGoColors.text;
    const secondary = DealGoColors.textSecondary;
    final baseline = Typography.material2021().black.apply(
      bodyColor: text,
      displayColor: text,
      fontFamily: DealGoTypography.fontFamily,
    );

    TextStyle readable(
      TextStyle? source, {
      required double fontSize,
      required FontWeight fontWeight,
      Color color = text,
      double height = 1.4,
      double letterSpacing = 0,
    }) {
      return (source ?? const TextStyle()).copyWith(
        fontSize: fontSize,
        fontWeight: fontWeight,
        color: color,
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
      primaryContainer: DealGoColors.subtlePurple,
      onPrimaryContainer: DealGoColors.primaryDeep,
      surface: DealGoColors.canvas,
      onSurface: text,
      onSurfaceVariant: secondary,
      surfaceContainerLowest: DealGoColors.card,
      outline: DealGoColors.border,
      outlineVariant: DealGoColors.divider,
      tertiary: DealGoColors.brandGreen,
      onTertiary: Colors.white,
      error: DealGoColors.danger,
      errorContainer: DealGoColors.dangerSurface,
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
      scaffoldBackgroundColor: DealGoColors.canvas,
      textTheme: textTheme,
      dividerColor: DealGoColors.border,
      splashFactory: InkRipple.splashFactory,
      materialTapTargetSize: MaterialTapTargetSize.padded,
      visualDensity: VisualDensity.standard,
      pageTransitionsTheme: DealGoPageTransitions.theme,
      iconTheme: const IconThemeData(color: text, size: 22),
      dividerTheme: const DividerThemeData(
        color: DealGoColors.divider,
        thickness: 1,
        space: 1,
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: DealGoColors.canvas,
        foregroundColor: text,
        elevation: 0,
        scrolledUnderElevation: 0,
        surfaceTintColor: Colors.transparent,
        centerTitle: true,
        titleTextStyle: textTheme.titleMedium,
        iconTheme: const IconThemeData(color: text, size: 22),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: DealGoColors.card,
        isDense: false,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: DealGoSpacing.s16,
          vertical: DealGoSpacing.s16,
        ),
        hintStyle: textTheme.bodyMedium?.copyWith(
          color: DealGoColors.textTertiary,
        ),
        labelStyle: textTheme.bodyMedium?.copyWith(color: secondary),
        floatingLabelStyle: textTheme.labelMedium?.copyWith(
          color: DealGoColors.primary,
        ),
        helperStyle: textTheme.bodySmall,
        errorStyle: textTheme.bodySmall?.copyWith(color: DealGoColors.danger),
        prefixIconColor: secondary,
        suffixIconColor: secondary,
        border: inputBorder(DealGoColors.border),
        enabledBorder: inputBorder(DealGoColors.border),
        disabledBorder: inputBorder(DealGoColors.divider),
        focusedBorder: inputBorder(DealGoColors.primary, 1.6),
        errorBorder: inputBorder(DealGoColors.danger),
        focusedErrorBorder: inputBorder(DealGoColors.danger, 1.6),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: DealGoColors.primary,
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
        backgroundColor: DealGoColors.card,
        selectedColor: DealGoColors.subtlePurple,
        side: const BorderSide(color: DealGoColors.border),
        labelStyle: textTheme.labelMedium,
        shape: const StadiumBorder(),
        showCheckmark: false,
      ),
      checkboxTheme: CheckboxThemeData(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
        side: const BorderSide(color: DealGoColors.border, width: 1.5),
        fillColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected)
              ? DealGoColors.primary
              : DealGoColors.card,
        ),
      ),
      radioTheme: RadioThemeData(
        fillColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected)
              ? DealGoColors.primary
              : DealGoColors.border,
        ),
      ),
      switchTheme: SwitchThemeData(
        thumbColor: const WidgetStatePropertyAll(Colors.white),
        trackOutlineColor: const WidgetStatePropertyAll(Colors.transparent),
        trackColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected)
              ? DealGoColors.primary
              : DealGoColors.border,
        ),
      ),
      progressIndicatorTheme: const ProgressIndicatorThemeData(
        color: DealGoColors.primary,
        linearTrackColor: DealGoColors.subtlePurple,
        circularTrackColor: Colors.transparent,
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: DealGoColors.card,
        surfaceTintColor: Colors.transparent,
        showDragHandle: true,
        dragHandleColor: DealGoColors.border,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(
            top: Radius.circular(DealGoRadius.sheet),
          ),
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: DealGoColors.card,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(DealGoRadius.card),
        ),
        titleTextStyle: textTheme.titleMedium,
        contentTextStyle: textTheme.bodyMedium,
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: DealGoColors.text,
        contentTextStyle: textTheme.bodyMedium?.copyWith(color: Colors.white),
        actionTextColor: DealGoColors.primaryLight,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(DealGoRadius.input),
        ),
      ),
      tooltipTheme: TooltipThemeData(
        decoration: BoxDecoration(
          color: DealGoColors.text,
          borderRadius: BorderRadius.circular(DealGoRadius.small),
        ),
        textStyle: textTheme.labelSmall?.copyWith(color: Colors.white),
      ),
      listTileTheme: ListTileThemeData(
        iconColor: DealGoColors.primary,
        titleTextStyle: textTheme.titleSmall,
        subtitleTextStyle: textTheme.bodySmall,
        minVerticalPadding: DealGoSpacing.s12,
      ),
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
