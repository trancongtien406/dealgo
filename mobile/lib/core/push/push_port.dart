/// Device push registration. Production FCM adapter is key-fill later (ADR-006).
abstract interface class PushPort {
  /// Local or provider device token; null when push is unavailable.
  Future<String?> currentToken();

  /// Ensure a token exists and attempt `POST /v1/me/push-tokens` when authorized.
  Future<void> ensureRegistered({required String accessToken});

  /// Logout: `DELETE /v1/me/push-tokens` so this device stops getting the
  /// previous account's notifications. Best-effort; never throws.
  Future<void> unregister({required String accessToken});

  /// Calls [onTap] with the push `data` when the user opens the app from a
  /// notification (cold start or background). Default: no-op (tests, stub).
  Future<void> listenForTaps(void Function(Map<String, Object?> data) onTap);

  /// A push that arrives while the app is open. Android shows no system
  /// banner for it, so the app shows its own (tap → same routing as a system
  /// notification). Default: no-op (tests, stub, iOS which shows a banner).
  Future<void> listenForeground(void Function(PushMessage message) onMessage);
}

/// Foreground push content (title/body are the server's Vietnamese copy).
class PushMessage {
  const PushMessage({this.title, this.body, this.data = const {}});

  final String? title;
  final String? body;
  final Map<String, Object?> data;
}
