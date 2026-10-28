import 'package:flutter/material.dart';

/// Shared motion tokens. Prefer these over ad-hoc Duration/Curve literals so
/// reduced-motion and future brand timing stay consistent.
abstract final class DealGoMotion {
  static const Duration fast = Duration(milliseconds: 150);
  static const Duration medium = Duration(milliseconds: 280);
  static const Duration slow = Duration(milliseconds: 420);

  static const Curve standard = Curves.easeOutCubic;
  static const Curve emphasized = Curves.easeInOutCubic;

  /// Platform accessibility: skip decorative motion when the user requests it.
  static bool prefersReducedMotion(BuildContext context) {
    return MediaQuery.disableAnimationsOf(context);
  }

  /// Endless decorative loops (pulse rings): off for reduced motion, muted
  /// tickers, and widget tests, where a loop would never let frames settle.
  static bool ambientLoops(BuildContext context) {
    final inWidgetTest = WidgetsBinding.instance.runtimeType
        .toString()
        .contains('TestWidgetsFlutterBinding');
    return !prefersReducedMotion(context) &&
        !inWidgetTest &&
        TickerMode.valuesOf(context).enabled;
  }

  static Duration durationFor(BuildContext context, Duration preferred) {
    return prefersReducedMotion(context) ? Duration.zero : preferred;
  }
}
