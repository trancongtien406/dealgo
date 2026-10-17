import 'package:flutter/foundation.dart';

import 'analytics_port.dart';

/// Debug-only sink so local runs can observe events without a vendor SDK.
class ConsoleAnalytics implements AnalyticsPort {
  const ConsoleAnalytics();

  @override
  Future<void> logEvent(
    String name, {
    Map<String, Object?> parameters = const {},
  }) async {
    if (kDebugMode) {
      debugPrint('analytics:event $name $parameters');
    }
  }

  @override
  Future<void> setUserId(String? userId) async {
    if (kDebugMode) {
      debugPrint('analytics:userId $userId');
    }
  }
}
