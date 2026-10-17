import 'push_port.dart';

/// Mock/test push: stable fake token, no network.
class FakePush implements PushPort {
  FakePush({this.token = 'fake-fcm-token'});

  final String token;
  final List<String> registerCalls = [];

  @override
  Future<String?> currentToken() async => token;

  @override
  Future<void> ensureRegistered({required String accessToken}) async {
    registerCalls.add(accessToken);
  }
}
