import 'push_port.dart';

/// Mock/test push: stable fake token, no network.
class FakePush implements PushPort {
  FakePush({this.token = 'fake-fcm-token'});

  final String token;
  final List<String> registerCalls = [];
  final List<String> unregisterCalls = [];

  @override
  Future<void> unregister({required String accessToken}) async {
    unregisterCalls.add(accessToken);
  }

  void Function(Map<String, Object?> data)? _onTap;
  void Function(PushMessage message)? _onForeground;

  @override
  Future<void> listenForTaps(
    void Function(Map<String, Object?> data) onTap,
  ) async {
    _onTap = onTap;
  }

  @override
  Future<void> listenForeground(
    void Function(PushMessage message) onMessage,
  ) async {
    _onForeground = onMessage;
  }

  /// Tests: simulate the user opening a notification.
  void emitTap(Map<String, Object?> data) => _onTap?.call(data);

  /// Tests: simulate a push arriving while the app is open.
  void emitForeground(PushMessage message) => _onForeground?.call(message);

  @override
  Future<String?> currentToken() async => token;

  @override
  Future<void> ensureRegistered({required String accessToken}) async {
    registerCalls.add(accessToken);
  }
}
