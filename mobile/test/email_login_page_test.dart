import 'package:dealgo/core/network/api_exception.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/auth_test_harness.dart';
import 'support/fake_identity_client.dart';
import 'support/memory_token_store.dart';

void main() {
  setUp(() async {});

  testWidgets('tapping email auth method navigates to email login page', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(430, 1200));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final client = FakeIdentityClient();
    await pumpDealGo(tester, client: client);

    expect(find.byKey(const Key('auth-method-email')), findsOneWidget);
    await tester.tap(find.byKey(const Key('auth-method-email')));
    await tester.pumpAndSettle();

    expect(find.text('Đăng nhập bằng Email'), findsOneWidget);
    expect(find.byKey(const Key('email-auth-tabs')), findsOneWidget);
    expect(find.byKey(const Key('email-field')), findsOneWidget);
    expect(find.byKey(const Key('password-field')), findsOneWidget);
    expect(find.byKey(const Key('email-submit-btn')), findsOneWidget);
    expect(find.text('Đăng nhập'), findsWidgets);
    expect(find.textContaining('Passkey'), findsNothing);
  });

  testWidgets('email login validates empty and invalid inputs', (tester) async {
    await tester.binding.setSurfaceSize(const Size(430, 1200));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final client = FakeIdentityClient();
    await pumpDealGo(tester, client: client);

    await tester.tap(find.byKey(const Key('auth-method-email')));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('email-submit-btn')));
    await tester.pump();
    expect(find.text('Vui lòng nhập địa chỉ email'), findsOneWidget);

    await tester.enterText(
      find.byKey(const Key('email-field')),
      'not-an-email',
    );
    await tester.tap(find.byKey(const Key('email-submit-btn')));
    await tester.pump();
    expect(find.text('Địa chỉ email không hợp lệ'), findsOneWidget);

    await tester.enterText(
      find.byKey(const Key('email-field')),
      'user@dealgo.vn',
    );
    await tester.tap(find.byKey(const Key('email-submit-btn')));
    await tester.pump();
    expect(find.text('Vui lòng nhập mật khẩu'), findsOneWidget);

    await tester.enterText(find.byKey(const Key('password-field')), 'short');
    await tester.tap(find.byKey(const Key('email-submit-btn')));
    await tester.pump();
    expect(find.text('Mật khẩu phải có ít nhất 8 ký tự'), findsOneWidget);
  });

  testWidgets('email register validates confirm password mismatch', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(430, 1400));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final client = FakeIdentityClient();
    await pumpDealGo(tester, client: client);

    await tester.tap(find.byKey(const Key('auth-method-email')));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('email-tab-register')));
    await tester.pumpAndSettle();

    expect(find.text('Đăng ký bằng Email'), findsOneWidget);
    expect(find.byKey(const Key('confirm-password-field')), findsOneWidget);
    expect(find.byKey(const Key('display-name-field')), findsOneWidget);

    await tester.enterText(
      find.byKey(const Key('email-field')),
      'new@dealgo.vn',
    );
    await tester.enterText(
      find.byKey(const Key('password-field')),
      'password123',
    );
    await tester.enterText(
      find.byKey(const Key('confirm-password-field')),
      'password999',
    );
    await tester.tap(find.byKey(const Key('email-submit-btn')));
    await tester.pump();
    expect(find.text('Mật khẩu xác nhận không khớp'), findsOneWidget);
  });

  testWidgets('email login navigates back to method picker', (tester) async {
    await tester.binding.setSurfaceSize(const Size(430, 1200));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final client = FakeIdentityClient();
    await pumpDealGo(tester, client: client);

    await tester.tap(find.byKey(const Key('auth-method-email')));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('back-to-phone-login-btn')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('auth-method-phone')), findsOneWidget);
  });

  testWidgets('email register asks for the emailed OTP before signing in', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(430, 1400));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final client = FakeIdentityClient(profile: customerProfile);
    final store = MemoryTokenStore();
    await pumpDealGo(
      tester,
      client: client,
      tokenStore: store,
      completePostAuth: true,
    );

    await tester.tap(find.byKey(const Key('auth-method-email')));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('email-tab-register')));
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byKey(const Key('email-field')),
      'test@dealgo.vn',
    );
    await tester.enterText(
      find.byKey(const Key('password-field')),
      'password123',
    );
    await tester.enterText(
      find.byKey(const Key('confirm-password-field')),
      'password123',
    );
    await tester.enterText(
      find.byKey(const Key('display-name-field')),
      'Test User',
    );
    await tester.tap(find.byKey(const Key('email-submit-btn')));
    await tester.pumpAndSettle(const Duration(seconds: 1));

    expect(client.registerEmailCalls, isNotEmpty);
    expect(client.registerEmailCalls.single.email, 'test@dealgo.vn');
    expect(await store.read(), isNull);
    expect(navLabel('Trang'), findsNothing);
    expect(
      find.textContaining('test@dealgo.vn', findRichText: true),
      findsOneWidget,
    );
    expect(find.byKey(const Key('otp-back')), findsOneWidget);

    await submitOtp(tester, '123456');
    await tester.pumpAndSettle(const Duration(seconds: 1));

    expect(client.verifyEmailCalls, [
      (challengeId: 'email-challenge-1', code: '123456'),
    ]);
    expect(client.verifyCalls, isEmpty);
    expect(navLabel('Trang'), findsOneWidget);
    // Single unified ride entry on home (ServiceRow).
    expect(find.text("Đặt xe"), findsOneWidget);
  });

  testWidgets('email register shows the invalid-code pane on a wrong OTP', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(430, 1400));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final client = FakeIdentityClient(profile: customerProfile)
      ..emailVerifyError = const ApiException(
        statusCode: 401,
        errorCode: 'AUTH_CODE_INVALID',
        message: 'Verification code is invalid',
      );
    final store = MemoryTokenStore();
    await pumpDealGo(tester, client: client, tokenStore: store);

    await tester.tap(find.byKey(const Key('auth-method-email')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('email-tab-register')));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const Key('email-field')),
      'bad@dealgo.vn',
    );
    await tester.enterText(
      find.byKey(const Key('password-field')),
      'password123',
    );
    await tester.enterText(
      find.byKey(const Key('confirm-password-field')),
      'password123',
    );
    await tester.tap(find.byKey(const Key('email-submit-btn')));
    await tester.pumpAndSettle(const Duration(seconds: 1));

    await submitOtp(tester, '000000');
    await tester.pumpAndSettle();

    // Title copy is owned by l10n (T87 shortened it); assert the pane.
    expect(find.byKey(const Key('auth-error')), findsOneWidget);
    // Header is a back arrow; only the pane button reads "Đổi email".
    expect(find.text('Đổi email'), findsOneWidget);
    expect(await store.read(), isNull);
  });

  testWidgets('email login with registered credentials reaches shell', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(430, 1200));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final client = FakeIdentityClient(profile: customerProfile);
    final challenge = await client.registerWithEmail(
      email: 'login@dealgo.vn',
      password: 'password123',
      displayName: 'Login User',
    );
    await client.verifyEmailRegistration(
      challengeId: challenge.challengeId,
      code: '123456',
    );
    client.registerEmailCalls.clear();
    client.verifyEmailCalls.clear();

    final store = MemoryTokenStore();
    await pumpDealGo(
      tester,
      client: client,
      tokenStore: store,
      completePostAuth: true,
    );

    await tester.tap(find.byKey(const Key('auth-method-email')));
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byKey(const Key('email-field')),
      'login@dealgo.vn',
    );
    await tester.enterText(
      find.byKey(const Key('password-field')),
      'password123',
    );
    await tester.tap(find.byKey(const Key('email-submit-btn')));
    await tester.pumpAndSettle(const Duration(seconds: 1));

    expect(client.loginEmailCalls, isNotEmpty);
    expect(client.loginEmailCalls.single.email, 'login@dealgo.vn');
    expect(client.passkeyOptionCalls, isEmpty);
    expect(navLabel('Trang'), findsOneWidget);
  });

  testWidgets(
    'email login of an unverified account continues on the OTP screen',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(430, 1200));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      final client = FakeIdentityClient(profile: customerProfile)
        ..seedUnverifiedEmailAccount('old@dealgo.vn', 'password123');
      final store = MemoryTokenStore();
      await pumpDealGo(
        tester,
        client: client,
        tokenStore: store,
        completePostAuth: true,
      );

      await tester.tap(find.byKey(const Key('auth-method-email')));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const Key('email-field')),
        'old@dealgo.vn',
      );
      await tester.enterText(
        find.byKey(const Key('password-field')),
        'password123',
      );
      await tester.tap(find.byKey(const Key('email-submit-btn')));
      await tester.pumpAndSettle(const Duration(seconds: 1));

      expect(await store.read(), isNull);
      expect(
        find.textContaining('old@dealgo.vn', findRichText: true),
        findsOneWidget,
      );
      expect(find.byKey(const Key('otp-back')), findsOneWidget);

      await submitOtp(tester, '123456');
      await tester.pumpAndSettle(const Duration(seconds: 1));

      expect(client.verifyEmailCalls, [
        (challengeId: 'email-activation-1', code: '123456'),
      ]);
      expect(navLabel('Trang'), findsOneWidget);
    },
  );

  testWidgets('a locked email code asks to start again instead of retrying', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(430, 1400));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final client = FakeIdentityClient(profile: customerProfile)
      ..emailVerifyError = const ApiException(
        statusCode: 429,
        errorCode: 'AUTH_CODE_LOCKED',
        message: 'Verification code is locked; start again',
      );
    await pumpDealGo(tester, client: client);

    await tester.tap(find.byKey(const Key('auth-method-email')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('email-tab-register')));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const Key('email-field')),
      'lock@dealgo.vn',
    );
    await tester.enterText(
      find.byKey(const Key('password-field')),
      'password123',
    );
    await tester.enterText(
      find.byKey(const Key('confirm-password-field')),
      'password123',
    );
    await tester.tap(find.byKey(const Key('email-submit-btn')));
    await tester.pumpAndSettle(const Duration(seconds: 1));

    await submitOtp(tester, '000000');
    await tester.pumpAndSettle();

    expect(
      find.text(
        'Bạn đã nhập sai quá số lần cho phép. Hãy quay lại và bắt đầu lại để nhận mã mới.',
      ),
      findsOneWidget,
    );
    // Header is a back arrow; only the pane button reads "Đổi email".
    expect(find.text('Đổi email'), findsOneWidget);
    expect(find.text('Thử lại'), findsNothing);
  });

  testWidgets('email login shows server invalid credentials error', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(430, 1200));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final client = FakeIdentityClient(profile: customerProfile);
    await pumpDealGo(tester, client: client);

    await tester.tap(find.byKey(const Key('auth-method-email')));
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byKey(const Key('email-field')),
      'missing@dealgo.vn',
    );
    await tester.enterText(
      find.byKey(const Key('password-field')),
      'password123',
    );
    await tester.tap(find.byKey(const Key('email-submit-btn')));
    await tester.pumpAndSettle();

    expect(find.text('Email hoặc mật khẩu không đúng'), findsOneWidget);
  });

  testWidgets(
    'forgot password: emailed code resets, then login works (DEC-PROD-045)',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(430, 1400));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      final client = FakeIdentityClient(profile: customerProfile)
        ..seedEmailAccount('forgot@dealgo.vn', 'old-password');
      await pumpDealGo(tester, client: client);

      await tester.tap(find.byKey(const Key('auth-method-email')));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const Key('email-field')),
        'forgot@dealgo.vn',
      );
      await tester.tap(find.byKey(const Key('email-forgot-password-btn')));
      await tester.pumpAndSettle();

      expect(find.text('Đặt lại mật khẩu'), findsWidgets);
      await tester.tap(find.byKey(const Key('forgot-send-btn')));
      await tester.pumpAndSettle();
      expect(client.passwordResetRequests, ['forgot@dealgo.vn']);
      expect(find.byKey(const Key('forgot-code-field')), findsOneWidget);

      await tester.enterText(find.byKey(const Key('forgot-code-field')), '12');
      await tester.tap(find.byKey(const Key('forgot-submit-btn')));
      await tester.pump();
      expect(find.text('Nhập đủ 6 chữ số của mã.'), findsOneWidget);

      await tester.enterText(
        find.byKey(const Key('forgot-code-field')),
        '000000',
      );
      await tester.enterText(
        find.byKey(const Key('forgot-password-field')),
        'new-password-1',
      );
      await tester.enterText(
        find.byKey(const Key('forgot-confirm-field')),
        'new-password-1',
      );
      await tester.tap(find.byKey(const Key('forgot-submit-btn')));
      await tester.pumpAndSettle();
      expect(find.text('Mã OTP không hợp lệ.'), findsOneWidget);

      await tester.enterText(
        find.byKey(const Key('forgot-code-field')),
        FakeIdentityClient.passwordResetCode,
      );
      await tester.tap(find.byKey(const Key('forgot-submit-btn')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('forgot-done')), findsOneWidget);
      expect(client.passwordResetConfirms.last.newPassword, 'new-password-1');

      await tester.tap(find.byKey(const Key('forgot-back-to-login')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('email-submit-btn')), findsOneWidget);
    },
  );

  testWidgets('forgot password: rate limit shows a friendly message', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(430, 1400));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final client = FakeIdentityClient(profile: customerProfile)
      ..passwordResetError = const ApiException(
        statusCode: 429,
        errorCode: 'AUTH_OTP_RATE_LIMITED',
        message: 'Too many reset codes for this email',
      );
    await pumpDealGo(tester, client: client);
    await tester.tap(find.byKey(const Key('auth-method-email')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('email-forgot-password-btn')));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const Key('forgot-email-field')),
      'a@dealgo.vn',
    );
    await tester.tap(find.byKey(const Key('forgot-send-btn')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('forgot-error')), findsOneWidget);
    expect(find.byKey(const Key('forgot-code-field')), findsNothing);
  });
}
