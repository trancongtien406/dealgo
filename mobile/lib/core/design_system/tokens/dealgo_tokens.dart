import 'package:flutter/material.dart';

/// Surfaces and text that follow light or dark. Brand hues stay fixed.
final class DealGoPalette {
  const DealGoPalette({
    required this.canvas,
    required this.card,
    required this.border,
    required this.divider,
    required this.text,
    required this.textSecondary,
    required this.textTertiary,
    required this.subtlePurple,
    required this.lavender,
    required this.dangerSurface,
    required this.warningSurface,
    required this.greenSurface,
    required this.amberSurface,
    required this.infoSurface,
    required this.skeletonBase,
    required this.skeletonHighlight,
    required this.scrim,
    required this.onPrimaryContainer,
  });

  final Color canvas;
  final Color card;
  final Color border;
  final Color divider;
  final Color text;
  final Color textSecondary;
  final Color textTertiary;
  final Color subtlePurple;
  final Color lavender;
  final Color dangerSurface;
  final Color warningSurface;
  final Color greenSurface;
  final Color amberSurface;
  final Color infoSurface;
  final Color skeletonBase;
  final Color skeletonHighlight;
  final Color scrim;
  final Color onPrimaryContainer;

  static const light = DealGoPalette(
    canvas: Color(0xFFFBFAFD),
    card: Color(0xFFFFFFFF),
    border: Color(0xFFE7E3EF),
    divider: Color(0xFFF0EDF5),
    text: Color(0xFF171B2C),
    textSecondary: Color(0xFF666B80),
    textTertiary: Color(0xFF8A8FA3),
    subtlePurple: Color(0xFFF2EAFF),
    lavender: Color(0xFFF6F2FF),
    dangerSurface: Color(0xFFFFF1F2),
    warningSurface: Color(0xFFFFF7ED),
    greenSurface: Color(0xFFECFDF3),
    amberSurface: Color(0xFFFFF4E5),
    infoSurface: Color(0xFFEFF6FF),
    skeletonBase: Color(0xFFEFEBF5),
    skeletonHighlight: Color(0xFFF9F7FC),
    scrim: Color(0x66171B2C),
    onPrimaryContainer: Color(0xFF4C1D95),
  );

  static const dark = DealGoPalette(
    canvas: Color(0xFF100E16),
    card: Color(0xFF1C1826),
    border: Color(0xFF322C40),
    divider: Color(0xFF2A2536),
    text: Color(0xFFF4F1FA),
    textSecondary: Color(0xFFB7B1C6),
    textTertiary: Color(0xFF8E879C),
    subtlePurple: Color(0xFF2A2140),
    lavender: Color(0xFF231C33),
    dangerSurface: Color(0xFF3A1822),
    warningSurface: Color(0xFF3A2A14),
    greenSurface: Color(0xFF12301F),
    amberSurface: Color(0xFF3A2812),
    infoSurface: Color(0xFF15243A),
    skeletonBase: Color(0xFF2A2536),
    skeletonHighlight: Color(0xFF3A3448),
    scrim: Color(0xCC000000),
    onPrimaryContainer: Color(0xFFC4B5FD),
  );

  /// Palette widgets read. Set from the resolved appearance before each frame.
  static DealGoPalette active = light;

  static void use(Brightness brightness) {
    active = brightness == Brightness.dark ? dark : light;
  }
}

/// Brand palette sampled from `/design` mockups (purple primary, green "Go").
///
/// Surface and text colors follow [DealGoPalette.active]. Brand hues do not.
abstract final class DealGoColors {
  static const Color primary = Color(0xFF6D28D9);
  static const Color primaryPressed = Color(0xFF5820B5);
  static const Color primaryLight = Color(0xFF8B5CF6);
  static const Color primaryDeep = Color(0xFF4C1D95);
  static Color get canvas => DealGoPalette.active.canvas;
  static Color get card => DealGoPalette.active.card;
  static Color get border => DealGoPalette.active.border;
  static Color get divider => DealGoPalette.active.divider;
  static Color get text => DealGoPalette.active.text;
  static Color get textSecondary => DealGoPalette.active.textSecondary;

  /// Placeholder / hint text. Still ≥ 4.5:1 on the canvas for 14sp+ copy.
  static Color get textTertiary => DealGoPalette.active.textTertiary;
  static const Color brandGreen = Color(0xFF16A34A);
  static Color get subtlePurple => DealGoPalette.active.subtlePurple;
  static Color get lavender => DealGoPalette.active.lavender;
  static const Color danger = Color(0xFFE11D48);
  static Color get dangerSurface => DealGoPalette.active.dangerSurface;
  static const Color warning = Color(0xFFB45309);
  static Color get warningSurface => DealGoPalette.active.warningSurface;
  static Color get greenSurface => DealGoPalette.active.greenSurface;
  static const Color amber = Color(0xFFD97706);
  static Color get amberSurface => DealGoPalette.active.amberSurface;
  static const Color info = Color(0xFF2563EB);
  static Color get infoSurface => DealGoPalette.active.infoSurface;
  static Color get skeletonBase => DealGoPalette.active.skeletonBase;
  static Color get skeletonHighlight => DealGoPalette.active.skeletonHighlight;
  static Color get scrim => DealGoPalette.active.scrim;
}

/// Soft, purple-tinted elevations (mockups never use hard grey shadows).
abstract final class DealGoShadows {
  static const List<BoxShadow> card = [
    BoxShadow(color: Color(0x0F4C1D95), blurRadius: 18, offset: Offset(0, 6)),
  ];

  static const List<BoxShadow> floating = [
    BoxShadow(color: Color(0x1F4C1D95), blurRadius: 28, offset: Offset(0, 10)),
  ];

  static const List<BoxShadow> button = [
    BoxShadow(color: Color(0x406D28D9), blurRadius: 16, offset: Offset(0, 6)),
  ];
}

abstract final class DealGoSpacing {
  static const double s2 = 2;
  static const double s4 = 4;
  static const double s6 = 6;
  static const double s8 = 8;
  static const double s12 = 12;
  static const double s14 = 14;
  static const double s16 = 16;
  static const double s20 = 20;
  static const double s24 = 24;
  static const double s32 = 32;
  static const double s40 = 40;
  static const double s48 = 48;
}

abstract final class DealGoRadius {
  static const double small = 8;
  static const double input = 12;
  static const double button = 16;
  static const double card = 20;
  static const double sheet = 28;
  static const double pill = 999;
}

abstract final class DealGoDimensions {
  static const double pageGutter = 16;
  static const double minTapTarget = 48;
  static const double buttonMinHeight = 52;
  static const double inputHeight = 52;
  static const double iconBadge = 44;
  static const double headerHeight = 56;
}

abstract final class DealGoDensity {
  /// Between blocks inside one screen.
  static const double blockGap = 20;

  /// Between blocks that change subject.
  static const double groupGap = 24;

  static const double cardPad = 12;

  /// Menu row and store row floor.
  static const double rowMinHeight = 96;

  static const double metaGap = 4;
}

abstract final class DealGoTypography {
  static const String fontFamily = 'BeVietnamPro';
}

/// Body [SafeArea] bottom padding: always on for iOS home indicator;
/// Android shell tabs often clear content themselves so bottom may stay false.
bool dealGoSafeAreaBottom(BuildContext context) =>
    Theme.of(context).platform == TargetPlatform.iOS;
