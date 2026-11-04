import 'package:dealgo/features/identity/data/device_passkey_platform.dart';
import 'package:dealgo/features/identity/domain/passkey_platform.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:passkeys/authenticator.dart';
import 'package:passkeys/types.dart';

class _FakeAuthenticator implements PasskeyAuthenticator {
  Exception? errorToThrow;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);

  @override
  bool get debugMode => false;

  @override
  Future<AuthenticateResponseType> authenticate(AuthenticateRequestType request) async {
    if (errorToThrow != null) {
      throw errorToThrow!;
    }
    return const AuthenticateResponseType(
      id: 'test-id',
      rawId: 'test-raw-id',
      clientDataJSON: 'test-client-data',
      authenticatorData: 'test-auth-data',
      signature: 'test-sig',
      userHandle: 'test-user-handle',
    );
  }

  @override
  Future<RegisterResponseType> register(RegisterRequestType request) async {
    if (errorToThrow != null) {
      throw errorToThrow!;
    }
    return const RegisterResponseType(
      id: 'reg-id',
      rawId: 'reg-raw-id',
      clientDataJSON: 'reg-client-data',
      attestationObject: 'reg-attestation',
      transports: [],
    );
  }
}

void main() {
  group('DevicePasskeyPlatform', () {
    late _FakeAuthenticator fakeAuth;
    late DevicePasskeyPlatform platform;

    final dummyOptions = <String, Object?>{
      'challenge': 'dummy-challenge',
      'rpId': 'dealgo.laptrinhapp.com',
    };

    setUp(() {
      fakeAuth = _FakeAuthenticator();
      platform = DevicePasskeyPlatform(authenticator: fakeAuth);
    });

    test('authenticate when preferImmediatelyAvailable=true maps PasskeyAuthCancelledException to noCredentials', () async {
      fakeAuth.errorToThrow = PasskeyAuthCancelledException();

      expect(
        () => platform.authenticate(dummyOptions, preferImmediatelyAvailable: true),
        throwsA(
          isA<PasskeyPlatformException>().having(
            (e) => e.kind,
            'kind',
            PasskeyFailureKind.noCredentials,
          ),
        ),
      );
    });

    test('authenticate when preferImmediatelyAvailable=false maps PasskeyAuthCancelledException to cancelled', () async {
      fakeAuth.errorToThrow = PasskeyAuthCancelledException();

      expect(
        () => platform.authenticate(dummyOptions, preferImmediatelyAvailable: false),
        throwsA(
          isA<PasskeyPlatformException>().having(
            (e) => e.kind,
            'kind',
            PasskeyFailureKind.cancelled,
          ),
        ),
      );
    });

    test('register maps PasskeyAuthCancelledException to cancelled', () async {
      fakeAuth.errorToThrow = PasskeyAuthCancelledException();

      final regOptions = <String, Object?>{
        'challenge': 'dummy-challenge',
        'rp': {'id': 'dealgo.laptrinhapp.com', 'name': 'DealGo'},
        'user': {'id': 'dummy-user-id', 'name': 'test', 'displayName': 'test'},
      };

      expect(
        () => platform.register(regOptions),
        throwsA(
          isA<PasskeyPlatformException>().having(
            (e) => e.kind,
            'kind',
            PasskeyFailureKind.cancelled,
          ),
        ),
      );
    });
  });
}
