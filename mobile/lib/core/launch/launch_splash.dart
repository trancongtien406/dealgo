import 'dart:async';

import 'package:flutter/widgets.dart';

import '../../features/identity/domain/auth_redirect.dart';
import '../../features/identity/domain/entities/auth_state.dart';

/// Keeps the native launch screen (iOS LaunchScreen.storyboard, Android
/// launch theme / Android 12 SplashScreen) on screen until the first real
/// route is known, so cold start goes brand screen -> first page with no
/// white frame and no second, different-looking splash.
///
/// Flutter shows the native launch screen until it draws its first frame;
/// [hold] defers that frame and [release] allows it. Widgets still build and
/// the router still resolves while held; only painting is postponed.
/// A timeout always releases, so a slow session restore can never freeze the
/// launch screen (the Dart `/splash` route looks identical anyway).
class LaunchSplash {
  LaunchSplash._();

  static const defaultTimeout = Duration(seconds: 3);

  static bool _held = false;
  static Timer? _timeout;

  static bool get isHeld => _held;

  static void hold({Duration timeout = defaultTimeout}) {
    if (_held) return;
    _held = true;
    WidgetsBinding.instance.deferFirstFrame();
    _timeout = Timer(timeout, release);
  }

  /// Idempotent; a no-op when nothing is held (tests, hot restart).
  static void release() {
    if (!_held) return;
    _held = false;
    _timeout?.cancel();
    _timeout = null;
    WidgetsBinding.instance.allowFirstFrame();
  }
}

/// True once cold start knows where the user goes: the session restore has
/// finished, post-auth flags are loaded and the router has left `/splash`.
bool launchRouteReady({
  required AuthState auth,
  required bool postAuthLoaded,
  required String location,
}) {
  if (auth is AuthRestoring || !postAuthLoaded) return false;
  return location != AuthRoutes.splash;
}
