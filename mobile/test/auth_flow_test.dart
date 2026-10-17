import 'dart:async';

import 'package:dealgo/core/network/api_exception.dart';
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

    expect(find.text('Xác minh số điện thoại'), findsOneWidget);
    expect(find.text('Xác minh và tiếp tục'), findsOneWidget);
  });

  testWidgets('verify success navigates into the customer shell', (
    tester,
  ) async {
    final client = FakeIdentityClient(profile: customerProfile);
    final store = MemoryTokenStore();
    await pumpDealGo(tester, client: client, tokenStore: store);

    await submitPhone(tester, '987654321');
    await submitOtp(tester, '123456');

    expect(client.verifyCalls, [(challengeId: 'challenge-1', code: '123456')]);
    expect(navLabel('Trang chủ'), findsOneWidget);
    expect(find.text('Đặt xe'), findsWidgets);
    expect(await store.read(), isNotNull);

    await tester.tap(navLabel('Tài khoản'));
    await tester.pumpAndSettle();
    expect(find.text('+84911111111'), findsOneWidget);
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

    expect(find.text('Mã xác thực không đúng'), findsOneWidget);
    expect(find.text('Thử lại'), findsOneWidget);
    expect(find.byType(NavigationBar), findsNothing);
  });

  testWidgets('logout returns to login', (tester) async {
    final client = FakeIdentityClient(profile: customerProfile);
    final store = MemoryTokenStore();
    await pumpDealGo(tester, client: client, tokenStore: store);

    await submitPhone(tester, '987654321');
    await submitOtp(tester, '123456');
    await tester.tap(navLabel('Tài khoản'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Đăng xuất'));
    await tester.tap(find.text('Đăng xuất'));
    await tester.pumpAndSettle();

    expect(await store.read(), isNull);
    expect(find.text('Số điện thoại'), findsOneWidget);
    expect(find.text('Tiếp tục'), findsOneWidget);
    expect(find.byType(NavigationBar), findsNothing);
  });

  testWidgets('no active grants still open the customer shell and show phone', (
    tester,
  ) async {
    final client = FakeIdentityClient(profile: sandboxProfile);
    await pumpDealGo(tester, client: client);

    await submitPhone(tester, '912345678');
    await submitOtp(tester, '123456');

    expect(navLabel('Trang chủ'), findsOneWidget);
    await tester.tap(navLabel('Tài khoản'));
    await tester.pumpAndSettle();
    expect(find.text('+84922222222'), findsOneWidget);
    expect(find.text('Đổi vai trò'), findsNothing);
  });

  testWidgets('S003 phone login page matches shared mockup layout and components', (
    tester,
  ) async {
    final client = FakeIdentityClient(profile: customerProfile);
    final store = MemoryTokenStore();
    await pumpDealGo(tester, client: client, tokenStore: store);

    // Verify S003 layout elements
    expect(find.text('Chào mừng bạn\nđến với DealGo!', findRichText: true), findsOneWidget);
    expect(find.text('DealGo', findRichText: true), findsWidgets);
    expect(find.text('Số điện thoại'), findsOneWidget);
    expect(find.byKey(const Key('phone-field')), findsOneWidget);
    expect(find.text('+84'), findsOneWidget);
    expect(
      find.text('Mã OTP sẽ được gửi để xác minh và bảo vệ tài khoản của bạn.'),
      findsOneWidget,
    );
    expect(find.text('Tiếp tục'), findsOneWidget);
  });
}

