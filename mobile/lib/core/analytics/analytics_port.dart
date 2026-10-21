/// Client analytics surface. Production vendor adapter is key-fill later.
abstract interface class AnalyticsPort {
  Future<void> logEvent(
    String name, {
    Map<String, Object?> parameters = const {},
  });

  Future<void> setUserId(String? userId);
}
