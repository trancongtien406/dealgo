import 'dart:async';

import 'package:dealgo/core/network/api_exception.dart';
import 'package:dealgo/features/identity/domain/passkey_platform.dart';
import 'package:dealgo/features/identity/presentation/pages/phone_input_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/auth_test_harness.dart';
import 'support/fake_identity_client.dart';
import 'support/memory_token_store.dart';

void main() {
  testWidgets('phone submit calls the fake client and navigates to OTP', (
    tester,
  ) async {
    final client = FakeIdentityClient();
    final gate = Completer<void>();
    client.challengeGate = gate;
    await pumpDealGo(tester, client: client);

    final phoneBtn = find.byKey(const Key('auth-method-phone'));
    if (phoneBtn.evaluate().isNotEmpty) {
      await tester.tap(phoneBtn);
      await tester.pumpAndSettle();
    }

    await tester.enterText(find.byKey(const Key('phone-field')), '987654321');
    await tester.pump();
    await tester.ensureVisible(find.text('Tiếp tục'));
    await tester.tap(find.text('Tiếp tục'));
    await tester.pump();

    expect(client.challengedPhones, ['+84987654321']);
    await tester.tap(find.text('Tiếp tục'), warnIfMissed: false);
    await tester.pump();
    expect(client.challengedPhones, hasLength(1));

    gate.complete();
    await tester.pumpAndSettle();

    expect(
      find.text('Xác minh số điện thoại', findRichText: true),
      findsOneWidget,
    );
    expect(find.text('Xác nhận'), findsOneWidget);
  });

  testWidgets('verify success navigates into the customer shell', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(400, 2400));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final client = FakeIdentityClient(profile: customerProfile);
    final store = MemoryTokenStore();
    await pumpDealGo(
      tester,
      client: client,
      tokenStore: store,
      completePostAuth: true,
    );

    await submitPhone(tester, '987654321');
    await submitOtp(tester, '123456');

    expect(client.verifyCalls, [(challengeId: 'challenge-1', code: '123456')]);
    expect(navLabel('Trang'), findsOneWidget);
    // Single unified ride entry on home (ServiceRow).
    expect(find.text("Đặt xe"), findsOneWidget);
    expect(await store.read(), isNotNull);

    await tester.tap(navLabel('Tôi'));
    await tester.pumpAndSettle();
    expect(find.text('Nguyễn Văn A'), findsWidgets);
  });

  testWidgets('verify success lands on profile setup when server needs it', (
    tester,
  ) async {
    final client = FakeIdentityClient(profile: needsProfileSetupProfile);
    await pumpDealGo(tester, client: client);

    await submitPhone(tester, '987654321');
    await submitOtp(tester, '123456');

    expect(find.text('Hoàn thiện hồ sơ'), findsOneWidget);
    expect(find.byType(NavigationBar), findsNothing);
  });

  testWidgets('verify 401 shows the error and stays on OTP', (tester) async {
    final client = FakeIdentityClient(
      verifyError: const ApiException(
        statusCode: 401,
        errorCode: 'AUTH_CODE_INVALID',
        message: 'Verification code is invalid',
      ),
    );
    await pumpDealGo(tester, client: client);

    await submitPhone(tester, '987654321');
    await submitOtp(tester, '000000');

    expect(find.byKey(const Key('auth-error')), findsOneWidget);
    expect(find.text('Thử lại'), findsOneWidget);
    expect(find.byType(NavigationBar), findsNothing);
  });

  testWidgets('logout returns to login', (tester) async {
    final client = FakeIdentityClient(profile: customerProfile);
    final store = MemoryTokenStore();
    await pumpDealGo(
      tester,
      client: client,
      tokenStore: store,
      completePostAuth: true,
    );

    await submitPhone(tester, '987654321');
    await submitOtp(tester, '123456');
    await tester.tap(navLabel('Tôi'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Đăng xuất'));
    await tester.tap(find.text('Đăng xuất'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('account-signout-confirm')));
    await tester.pumpAndSettle();

    expect(client.revokeCalls, ['access-token']);
    expect(await store.read(), isNull);
    expect(find.byKey(const Key('auth-method-phone')), findsOneWidget);
    expect(find.byKey(const Key('auth-method-passkey')), findsOneWidget);
    expect(find.byKey(const Key('auth-method-email')), findsOneWidget);
    expect(find.byType(NavigationBar), findsNothing);
  });

  testWidgets('no active grants still open the customer shell and show phone', (
    tester,
  ) async {
    final client = FakeIdentityClient(profile: sandboxProfile);
    await pumpDealGo(tester, client: client, completePostAuth: true);

    await submitPhone(tester, '912345678');
    await submitOtp(tester, '123456');

    expect(navLabel('Trang'), findsOneWidget);
    await tester.tap(navLabel('Tôi'));
    await tester.pumpAndSettle();
    expect(find.text('Sandbox'), findsWidgets);
    expect(find.text('Đổi vai trò'), findsNothing);
  });

  testWidgets('S003 login method picker matches locked layout', (tester) async {
    final client = FakeIdentityClient(profile: customerProfile);
    final store = MemoryTokenStore();
    await pumpDealGo(tester, client: client, tokenStore: store);

    expect(
      find.text('Chào mừng đến với\nDealGo', findRichText: true),
      findsOneWidget,
    );
    expect(find.text('Chọn cách đăng nhập để tiếp tục.'), findsNothing);
    expect(
      find.text(
        'Nhập số điện thoại để tiếp tục đặt xe,\ngọi đồ ăn và mua sắm.',
      ),
      findsNothing,
    );
    expect(find.text('Trợ giúp'), findsOneWidget);
    expect(find.byKey(const Key('auth-method-passkey')), findsOneWidget);
    expect(find.byKey(const Key('auth-method-phone')), findsOneWidget);
    expect(find.byKey(const Key('auth-method-email')), findsOneWidget);
    expect(find.text('Tiếp tục với passkey'), findsOneWidget);
    expect(find.text('Số điện thoại'), findsOneWidget);
    expect(find.text('Email'), findsOneWidget);
    expect(find.byKey(const Key('phone-field')), findsNothing);
  });

  testWidgets('phone method opens phone input page without field on /login', (
    tester,
  ) async {
    await pumpDealGo(tester, client: FakeIdentityClient());

    expect(find.byKey(const Key('phone-field')), findsNothing);
    await tester.tap(find.byKey(const Key('auth-method-phone')));
    await tester.pumpAndSettle();

    expect(
      find.descendant(
        of: find.byType(PhoneInputPage),
        matching: find.text('Đăng nhập'),
      ),
      findsOneWidget,
    );
    expect(find.byKey(const Key('phone-field')), findsOneWidget);
    expect(find.byKey(const Key('phone-submit-btn')), findsOneWidget);
  });

  testWidgets('passkey sign-in starts without asking for phone or email', (
    tester,
  ) async {
    final client = FakeIdentityClient(profile: customerProfile);
    await pumpDealGo(tester, client: client);

    await tester.ensureVisible(find.byKey(const Key('auth-method-passkey')));
    expect(find.text('Tiếp tục với passkey'), findsOneWidget);
    await tester.tap(find.byKey(const Key('auth-method-passkey')));
    await tester.pumpAndSettle();

    expect(client.passkeyOptionCalls, [true]);
    expect(client.passkeyVerifyCalls, hasLength(1));
    expect(find.byKey(const Key('phone-field')), findsNothing);
  });

  testWidgets('one passkey button signs up when the device has no passkey', (
    tester,
  ) async {
    final client = FakeIdentityClient(profile: customerProfile);
    final passkeys = FakePasskeyPlatform()
      ..authenticateFailure = PasskeyFailureKind.noCredentials;
    await pumpDealGo(tester, client: client, passkeyPlatform: passkeys);

    await tester.ensureVisible(find.byKey(const Key('auth-method-passkey')));
    await tester.tap(find.byKey(const Key('auth-method-passkey')));
    await tester.pumpAndSettle();

    expect(client.passkeyVerifyCalls, isEmpty);
    expect(passkeys.registerCalls, hasLength(1));
    expect(client.passkeySignupVerifyCalls, hasLength(1));
  });
}
