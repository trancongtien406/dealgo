import 'package:flutter/foundation.dart';

/// Bridges push / in-app inbox taps to go_router locations.
/// Navigation is intentionally no-op until deep-link registration is wired.
class NotificationRouter {
  NotificationRouter({this.onNavigate});

  void Function(String location)? onNavigate;

  void bindNavigator(void Function(String location) navigate) {
    onNavigate = navigate;
  }

  /// Inbox / FCM payload may carry a path like `/customer/ride/tracking/...`.
  void openPath(String? path) {
    final location = path?.trim() ?? '';
    if (location.isEmpty || !location.startsWith('/')) {
      return;
    }
    final navigate = onNavigate;
    if (navigate == null) {
      if (kDebugMode) {
        debugPrint('NotificationRouter: no navigator bound for $location');
      }
      return;
    }
    navigate(location);
  }
}
