import 'package:flutter/material.dart';

abstract final class DealGoColors {
  static const Color primary = Color(0xFF6D28D9);
  static const Color primaryPressed = Color(0xFF5820B5);
  static const Color canvas = Color(0xFFFBFAFD);
  static const Color card = Color(0xFFFFFFFF);
  static const Color border = Color(0xFFE7E3EF);
  static const Color text = Color(0xFF171B2C);
  static const Color textSecondary = Color(0xFF666B80);
  static const Color brandGreen = Color(0xFF16A34A);
  static const Color subtlePurple = Color(0xFFF2EAFF);
  static const Color danger = Color(0xFFE11D48);
  static const Color dangerSurface = Color(0xFFFFF1F2);
  static const Color warning = Color(0xFFB45309);
  static const Color warningSurface = Color(0xFFFFF7ED);
  static const Color greenSurface = Color(0xFFECFDF3);
  static const Color amber = Color(0xFFD97706);
  static const Color amberSurface = Color(0xFFFFF4E5);
}

abstract final class DealGoSpacing {
  static const double s4 = 4;
  static const double s8 = 8;
  static const double s12 = 12;
  static const double s16 = 16;
  static const double s20 = 20;
  static const double s24 = 24;
  static const double s32 = 32;
}

abstract final class DealGoRadius {
  static const double input = 12;
  static const double button = 16;
  static const double card = 20;
}

abstract final class DealGoDimensions {
  static const double pageGutter = 16;
  static const double minTapTarget = 48;
  static const double buttonMinHeight = 52;
}
