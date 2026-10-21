import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'dealgo_motion.dart';

/// go_router page builders using [DealGoMotion]. Apply on high-traffic
/// crossings (role picker → shell) as the pattern; do not wrap every route yet.
CustomTransitionPage<void> dealgoFadeSlidePage({
  required LocalKey key,
  required Widget child,
  Duration? duration,
}) {
  return CustomTransitionPage<void>(
    key: key,
    child: child,
    transitionDuration: duration ?? DealGoMotion.medium,
    reverseTransitionDuration: duration ?? DealGoMotion.fast,
    transitionsBuilder: (context, animation, secondaryAnimation, child) {
      if (DealGoMotion.prefersReducedMotion(context)) {
        return child;
      }
      final curved = CurvedAnimation(
        parent: animation,
        curve: DealGoMotion.standard,
      );
      return FadeTransition(
        opacity: curved,
        child: SlideTransition(
          position: Tween<Offset>(
            begin: const Offset(0, 0.04),
            end: Offset.zero,
          ).animate(curved),
          child: child,
        ),
      );
    },
  );
}

/// App-wide route transitions: light fade-forward on Android, native slide on
/// iOS. Reduced-motion users get the platform's own handling.
abstract final class DealGoPageTransitions {
  static const PageTransitionsTheme theme = PageTransitionsTheme(
    builders: {
      TargetPlatform.android: FadeForwardsPageTransitionsBuilder(),
      TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
    },
  );
}
