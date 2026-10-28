import 'package:dealgo/features/identity/domain/auth_redirect.dart';
import 'package:dealgo/features/identity/domain/entities/auth_method_policy.dart';
import 'package:dealgo/features/identity/domain/entities/auth_state.dart';
import 'package:dealgo/features/identity/presentation/auth_methods_store.dart';
import 'package:dealgo/core/auth/token_store.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/fake_identity_client.dart';

const _tokens = StoredTokens(accessToken: 'access', refreshToken: 'refresh');

bool _passkeyOnly(String method) => method == AuthMethodPolicy.passkey;

void main() {
  const signedOut = AuthSignedOut();
  const restoring = AuthRestoring();

  final disabledPages = [
    '/login/phone',
    '/login/email',
    '/login/email/forgot',
    '/login/otp?challengeId=abc&phone=%2B84987654321',
    '/login/otp?challengeId=abc&email=a%40b.vn',
  ];

  test('pages of switched-off methods redirect to login, deep links too', () {
    for (final auth in [signedOut, restoring]) {
      for (final page in disabledPages) {
        expect(
          authRedirect(auth, Uri.parse(page), methodAvailable: _passkeyOnly),
          AuthRoutes.login,
          reason: '$auth $page',
        );
      }
      expect(
        authRedirect(auth, Uri.parse('/login'), methodAvailable: _passkeyOnly),
        isNull,
      );
    }
  });

  test('pages of switched-on methods stay reachable', () {
    bool all(String _) => true;
    for (final page in disabledPages) {
      expect(
        authRedirect(signedOut, Uri.parse(page), methodAvailable: all),
        isNull,
        reason: page,
      );
    }
    bool phoneOnly(String m) => m == AuthMethodPolicy.phoneSms;
    expect(
      authRedirect(
        signedOut,
        Uri.parse('/login/phone'),
        methodAvailable: phoneOnly,
      ),
      isNull,
    );
    expect(
      authRedirect(
        signedOut,
        Uri.parse('/login/email'),
        methodAvailable: phoneOnly,
      ),
      AuthRoutes.login,
    );
  });

  test('change password is unreachable while email sign-in is off', () {
    final customer = AuthSignedIn(tokens: _tokens, profile: customerProfile);
    expect(
      authRedirect(
        customer,
        Uri.parse('/customer/account/change-password'),
        profileSetupCompleted: true,
        methodAvailable: _passkeyOnly,
      ),
      '/customer/account/security',
    );
    expect(
      authRedirect(
        customer,
        Uri.parse('/customer/account/change-password'),
        profileSetupCompleted: true,
        methodAvailable: (_) => true,
      ),
      isNull,
    );
  });

  test('a store that has not answered yet keeps method pages closed', () async {
    final store = AuthMethodsStore(
      () async => const [AuthMethodPolicy(method: 'PASSKEY', enabled: true)],
      cache: MemoryAuthMethodsCache(),
    );
    expect(
      authRedirect(
        signedOut,
        Uri.parse('/login/phone'),
        methodAvailable: store.isEnabled,
      ),
      AuthRoutes.login,
    );
    await store.load();
    // Server answers passkey only (the public list omits disabled methods).
    for (final page in disabledPages) {
      expect(
        authRedirect(
          signedOut,
          Uri.parse(page),
          methodAvailable: store.isEnabled,
        ),
        AuthRoutes.login,
      );
    }
    store.dispose();
  });
}
