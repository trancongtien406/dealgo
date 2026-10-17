/// Device push registration. Production FCM adapter is key-fill later (ADR-006).
abstract interface class PushPort {
  /// Local or provider device token; null when push is unavailable.
  Future<String?> currentToken();

  /// Ensure a token exists and attempt `POST /v1/me/push-tokens` when authorized.
  Future<void> ensureRegistered({required String accessToken});
}
