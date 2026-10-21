import 'package:flutter/foundation.dart';
import 'package:go_router/go_router.dart';

import 'deep_link_parser.dart';

/// Thin go_router hook for incoming URIs. Call from platform channel /
/// app_links later; safe to leave unbound until OS registration exists.
class DeepLinkRouterHook {
  DeepLinkRouterHook({this.parser = const DeepLinkParser(), this.router});

  final DeepLinkParser parser;
  GoRouter? router;

  void attach(GoRouter value) {
    router = value;
  }

  /// Returns true when the URI was recognized and navigation was attempted.
  bool handle(Uri uri) {
    final location = parser.parse(uri);
    if (location == null) {
      return false;
    }
    final goRouter = router;
    if (goRouter == null) {
      if (kDebugMode) {
        debugPrint('DeepLinkRouterHook: router not attached for $location');
      }
      return false;
    }
    goRouter.go(location);
    return true;
  }
}
