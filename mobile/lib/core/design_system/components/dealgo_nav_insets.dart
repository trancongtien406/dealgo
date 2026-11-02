import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

import '../tokens/dealgo_tokens.dart';

/// Geometry of the floating role tab bar ([DealGoTabBar]).
///
/// From top to bottom: [overhang] (the raised active circle above the pill),
/// the pill itself ([barHeight]) and [bottomGap] between the pill and the
/// screen edge (home indicator / system navigation included).
@immutable
class DealGoNavBarMetrics {
  const DealGoNavBarMetrics({
    required this.overhang,
    required this.barHeight,
    required this.bottomGap,
    required this.bottomInset,
  });

  /// Height of the active circle that rises above the pill.
  final double overhang;

  /// Height of the pill (icon + label row).
  final double barHeight;

  /// Space between the pill and the bottom screen edge.
  final double bottomGap;

  /// System inset under the bar (`viewPadding.bottom`).
  final double bottomInset;

  /// Full box of the bar widget, circle included.
  double get totalHeight => overhang + barHeight + bottomGap;
}

/// Pill height on every platform (≥ 48 tap target).
const double kDealGoNavBarHeight = 58;

/// Raised circle height above the pill.
const double kDealGoNavOverhang = 20;

/// Horizontal inset of the floating pill from the screen edges.
const double kDealGoNavSideMargin = 12;

/// iOS: the pill sits 10 above the screen bottom, or just above the home
/// indicator (inset − 10) on Face ID devices.
/// Android (edge-to-edge): the pill sits 6 above the system navigation
/// (`viewPadding.bottom`: ~48dp 3-button, ~16–24dp gesture), or 10 above the
/// edge without one.
/// Uses viewPadding (not padding) so the bar does not jump when the keyboard opens.
DealGoNavBarMetrics dealGoNavBarMetrics(
  TargetPlatform platform,
  double viewPaddingBottom,
) {
  final inset = viewPaddingBottom < 0 ? 0.0 : viewPaddingBottom;
  final isIos = platform == TargetPlatform.iOS;
  final double gap;
  if (inset <= 0) {
    gap = 10;
  } else if (isIos) {
    gap = math.max(inset - 10, 8);
  } else {
    gap = inset + 6;
  }
  return DealGoNavBarMetrics(
    overhang: kDealGoNavOverhang,
    barHeight: kDealGoNavBarHeight,
    bottomGap: gap,
    bottomInset: inset,
  );
}

/// Scroll padding so the last item clears whatever covers the screen bottom:
/// the floating tab bar inside a role shell ([FloatingNavBody] publishes its
/// height as `MediaQuery.padding.bottom`), otherwise the home indicator /
/// system navigation. Content still scrolls behind the bar. Put FAB or sticky
/// bar room in [base]'s bottom. Inside a bottom [SafeArea] this adds nothing.
EdgeInsets dealGoScrollPadding(
  BuildContext context, [
  EdgeInsets base = const EdgeInsets.only(bottom: DealGoSpacing.s16),
]) => base.copyWith(bottom: base.bottom + MediaQuery.paddingOf(context).bottom);

DealGoNavBarMetrics dealGoNavBarMetricsOf(BuildContext context) =>
    dealGoNavBarMetrics(
      defaultTargetPlatform,
      MediaQuery.viewPaddingOf(context).bottom,
    );

/// Android 15+ enforces edge-to-edge; opt in on every Android version so insets are consistent
/// and the system nav bar is transparent over our tab bar. No-op on iOS.
void enableAndroidEdgeToEdge() {
  if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) return;
  SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
  applySystemNavigationStyle(Brightness.light);
}

/// Android system-nav icons. Light icons on a dark app, dark icons on a light app.
void applySystemNavigationStyle(Brightness brightness) {
  if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) return;
  SystemChrome.setSystemUIOverlayStyle(
    SystemUiOverlayStyle(
      systemNavigationBarColor: const Color(0x00000000),
      systemNavigationBarDividerColor: const Color(0x00000000),
      systemNavigationBarContrastEnforced: false,
      systemNavigationBarIconBrightness: brightness == Brightness.dark
          ? Brightness.light
          : Brightness.dark,
    ),
  );
}
