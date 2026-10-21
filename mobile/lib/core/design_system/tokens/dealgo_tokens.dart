import 'package:flutter/material.dart';

/// Brand palette sampled from `/design` mockups (purple primary, green "Go").
abstract final class DealGoColors {
  static const Color primary = Color(0xFF6D28D9);
  static const Color primaryPressed = Color(0xFF5820B5);
  static const Color primaryLight = Color(0xFF8B5CF6);
  static const Color primaryDeep = Color(0xFF4C1D95);
  static const Color canvas = Color(0xFFFBFAFD);
  static const Color card = Color(0xFFFFFFFF);
  static const Color border = Color(0xFFE7E3EF);
  static const Color divider = Color(0xFFF0EDF5);
  static const Color text = Color(0xFF171B2C);
  static const Color textSecondary = Color(0xFF666B80);

  /// Placeholder / hint text. Still ≥ 4.5:1 on white for 14sp+ copy.
  static const Color textTertiary = Color(0xFF8A8FA3);
  static const Color brandGreen = Color(0xFF16A34A);
  static const Color subtlePurple = Color(0xFFF2EAFF);
  static const Color lavender = Color(0xFFF6F2FF);
  static const Color danger = Color(0xFFE11D48);
  static const Color dangerSurface = Color(0xFFFFF1F2);
  static const Color warning = Color(0xFFB45309);
  static const Color warningSurface = Color(0xFFFFF7ED);
  static const Color greenSurface = Color(0xFFECFDF3);
  static const Color amber = Color(0xFFD97706);
  static const Color amberSurface = Color(0xFFFFF4E5);
  static const Color info = Color(0xFF2563EB);
  static const Color infoSurface = Color(0xFFEFF6FF);
  static const Color skeletonBase = Color(0xFFEFEBF5);
  static const Color skeletonHighlight = Color(0xFFF9F7FC);
  static const Color scrim = Color(0x66171B2C);
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

abstract final class DealGoTypography {
  static const String fontFamily = 'BeVietnamPro';
}

/// Body [SafeArea] bottom padding: always on for iOS home indicator;
/// Android shell tabs often clear content themselves so bottom may stay false.
bool dealGoSafeAreaBottom(BuildContext context) =>
    Theme.of(context).platform == TargetPlatform.iOS;
