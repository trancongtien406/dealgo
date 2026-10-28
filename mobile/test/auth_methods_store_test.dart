import 'dart:async';

import 'package:dealgo/app/dealgo_app.dart';
import 'package:dealgo/core/auth/token_store.dart';
import 'package:dealgo/core/network/api_exception.dart';
import 'package:dealgo/features/identity/data/models/auth_method_policy_model.dart';
import 'package:dealgo/features/identity/domain/auth_redirect.dart';
import 'package:dealgo/features/identity/domain/entities/auth_method_policy.dart';
import 'package:dealgo/features/identity/presentation/auth_methods_store.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/auth_test_harness.dart';
import 'support/fake_identity_client.dart';

const _passkeyOnly = [
  AuthMethodPolicyModel(method: AuthMethodPolicy.passkey, enabled: true),
  AuthMethodPolicyModel(method: AuthMethodPolicy.phoneSms, enabled: false),
  AuthMethodPolicyModel(method: AuthMethodPolicy.email, enabled: false),
];

const _all = [
  AuthMethodPolicy(method: AuthMethodPolicy.passkey, enabled: true),
  AuthMethodPolicy(method: AuthMethodPolicy.phoneSms, enabled: true),
  AuthMethodPolicy(method: AuthMethodPolicy.email, enabled: true),
];

const _offline = ApiException(
  statusCode: 0,
  message: 'offline',
  errorCode: 'NETWORK_ERROR',
);

/// Server answers only when the test completes [gate]; can fail first.
class _GatedIdentityClient extends FakeIdentityClient {
  _GatedIdentityClient({this.failures = 0}) {
    authMethods = _passkeyOnly;
  }

  Completer<void> gate = Completer<void>();
  int failures;
  int calls = 0;

  @override
  Future<List<AuthMethodPolicyModel>> getAuthMethods() async {
    calls++;
    await gate.future;
    if (failures > 0) {
      failures--;
      throw _offline;
    }
    return authMethods;
  }
}

final _phone = find.byKey(const Key('auth-method-phone'));
final _email = find.byKey(const Key('auth-method-email'));
final _passkey = find.byKey(const Key('auth-method-passkey'));
final _loading = find.byKey(const Key('auth-methods-loading'));
final _error = find.byKey(const Key('auth-methods-error'));

Future<void> _pumpApp(
  WidgetTester tester,
  _GatedIdentityClient client, {
  AuthMethodsCache? cache,
}) async {
  await tester.pumpWidget(
    DealGoApp(
      identityClient: client,
      authMethodsCache: cache,
      tokenStore: MemoryTokenStore(),
      postAuthGate: incompletePostAuthGate(),
      initialLocation: AuthRoutes.login,
    ),
  );
}

/// Pumps frame by frame and fails if a switched-off method is ever drawn.
Future<void> _pumpFramesNeverShowing(
  WidgetTester tester,
  List<Finder> forbidden, {
  int frames = 40,
}) async {
  for (var i = 0; i < frames; i++) {
    await tester.pump(const Duration(milliseconds: 16));
    for (final finder in forbidden) {
      expect(finder, findsNothing, reason: 'frame $i drew $finder');
    }
  }
}

void main() {
  group('AuthMethodsStore', () {
    test('stays loading until an answer exists; never guesses', () async {
      final answer = Completer<List<AuthMethodPolicy>>();
      final store = AuthMethodsStore(
        () => answer.future,
        cache: MemoryAuthMethodsCache(),
      );
      final pending = store.load();
      await pumpEventQueue();
      expect(store.status, AuthMethodsStatus.loading);
      expect(store.isEnabled(AuthMethodPolicy.phoneSms), isFalse);
      answer.complete(_passkeyOnly);
      await pending;
      expect(store.status, AuthMethodsStatus.ready);
      expect(store.isEnabled(AuthMethodPolicy.passkey), isTrue);
      expect(store.isEnabled(AuthMethodPolicy.phoneSms), isFalse);
    });

    test('serves the cache first, then revalidates and persists', () async {
      final cache = MemoryAuthMethodsCache(_all);
      final answer = Completer<List<AuthMethodPolicy>>();
      final store = AuthMethodsStore(() => answer.future, cache: cache);
      final pending = store.load();
      await pumpEventQueue();
      expect(store.status, AuthMethodsStatus.ready);
      expect(store.isEnabled(AuthMethodPolicy.email), isTrue);
      answer.complete(_passkeyOnly);
      await pending;
      expect(store.isEnabled(AuthMethodPolicy.email), isFalse);
      expect(cache.value, _passkeyOnly);
    });

    test('shares one request between concurrent loads', () async {
      var calls = 0;
      final store = AuthMethodsStore(() async {
        calls++;
        return _passkeyOnly;
      }, cache: MemoryAuthMethodsCache());
      await Future.wait([store.load(), store.load(), store.load()]);
      expect(calls, 1);
    });

    test('fails only when nothing is known; retry recovers', () async {
      var fail = true;
      final store = AuthMethodsStore(() async {
        if (fail) throw _offline;
        return _passkeyOnly;
      }, cache: MemoryAuthMethodsCache());
      await store.load();
      expect(store.status, AuthMethodsStatus.failed);
      expect(store.error, _offline);
      fail = false;
      await store.retry();
      expect(store.status, AuthMethodsStatus.ready);
    });

    test('keeps the cached answer when the refresh fails', () async {
      final store = AuthMethodsStore(
        () async => throw _offline,
        cache: MemoryAuthMethodsCache(_passkeyOnly),
      );
      await store.load();
      expect(store.status, AuthMethodsStatus.ready);
      expect(store.isEnabled(AuthMethodPolicy.passkey), isTrue);
    });

    test('does not notify when the server repeats the cache', () async {
      final store = AuthMethodsStore(
        () async => _passkeyOnly,
        cache: MemoryAuthMethodsCache(_passkeyOnly),
      );
      var notifications = 0;
      store.addListener(() => notifications++);
      await store.load();
      expect(notifications, 1); // loading -> ready (cache)
    });
  });

  group('S003 sign-in picker', () {
    testWidgets('cold start never draws a method the server switched off', (
      tester,
    ) async {
      final client = _GatedIdentityClient();
      await _pumpApp(tester, client);
      await _pumpFramesNeverShowing(tester, [_phone, _email, _passkey]);
      expect(_loading, findsOneWidget);

      client.gate.complete();
      await _pumpFramesNeverShowing(tester, [_phone, _email]);
      await tester.pumpAndSettle();
      expect(_passkey, findsOneWidget);
      expect(_loading, findsNothing);
      expect(_phone, findsNothing);
      expect(_email, findsNothing);
    });

    testWidgets('returning user sees the cached methods on the first frame', (
      tester,
    ) async {
      final client = _GatedIdentityClient();
      await _pumpApp(
        tester,
        client,
        cache: MemoryAuthMethodsCache([for (final m in _passkeyOnly) m]),
      );
      await tester.pump();
      await tester.pump();
      expect(_loading, findsNothing);
      expect(_passkey, findsOneWidget);
      expect(_phone, findsNothing);
      client.gate.complete();
      await tester.pumpAndSettle();
      expect(_passkey, findsOneWidget);
      expect(_phone, findsNothing);
    });

    testWidgets('a server change after the cache animates in, not a jump', (
      tester,
    ) async {
      final client = _GatedIdentityClient()
        ..authMethods = const [
          AuthMethodPolicyModel(
            method: AuthMethodPolicy.passkey,
            enabled: true,
          ),
          AuthMethodPolicyModel(
            method: AuthMethodPolicy.phoneSms,
            enabled: true,
          ),
        ];
      await _pumpApp(
        tester,
        client,
        cache: MemoryAuthMethodsCache([..._passkeyOnly]),
      );
      await tester.pump();
      await tester.pump();
      client.gate.complete();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 60));
      expect(find.byType(AnimatedSize), findsWidgets);
      await tester.pumpAndSettle();
      expect(_phone, findsOneWidget);
      expect(_passkey, findsOneWidget);
    });

    testWidgets('offline cold start shows retry, then the real methods', (
      tester,
    ) async {
      final client = _GatedIdentityClient(failures: 1);
      client.gate.complete();
      await _pumpApp(tester, client);
      await _pumpFramesNeverShowing(tester, [_phone, _email, _passkey]);
      await tester.pumpAndSettle();
      expect(_error, findsOneWidget);
      expect(find.text('Thử lại'), findsOneWidget);

      await tester.ensureVisible(find.text('Thử lại'));
      await tester.tap(find.text('Thử lại'));
      await tester.pumpAndSettle();
      expect(_error, findsNothing);
      expect(_passkey, findsOneWidget);
      expect(_phone, findsNothing);
      expect(_email, findsNothing);
      expect(client.calls, 2);
    });

    testWidgets('production config (passkey only) renders a single option', (
      tester,
    ) async {
      final client = _GatedIdentityClient();
      client.gate.complete();
      await _pumpApp(tester, client);
      await tester.pumpAndSettle();
      expect(_passkey, findsOneWidget);
      expect(_phone, findsNothing);
      expect(_email, findsNothing);
      expect(find.byKey(const Key('auth-methods-empty')), findsNothing);
    });
  });
}
