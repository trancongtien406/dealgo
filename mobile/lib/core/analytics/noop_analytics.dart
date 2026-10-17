import 'analytics_port.dart';

class NoopAnalytics implements AnalyticsPort {
  const NoopAnalytics();

  @override
  Future<void> logEvent(
    String name, {
    Map<String, Object?> parameters = const {},
  }) async {}

  @override
  Future<void> setUserId(String? userId) async {}
}
