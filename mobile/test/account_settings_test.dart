import 'package:dealgo/features/account_settings/data/account_settings_remote_datasource.dart';
import 'package:dealgo/core/network/api_exception.dart';
import 'package:dealgo/features/account_settings/domain/account_settings.dart';
import 'package:dealgo/features/identity/domain/passkey_platform.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/auth_test_harness.dart';
import 'support/fake_identity_client.dart';

void main() {
  test('prefs decode defaults promotion/news off', () {
    final prefs = decodeNotificationPrefs({'ride': true, 'food': false});
    expect(prefs.ride, isTrue);
    expect(prefs.food, isFalse);
    expect(prefs.promotion, isFalse);
    expect(prefs.news, isFalse);
  });

  testWidgets('S024 saves notification preferences', (tester) async {
    final repo = FakeAccountSettingsRepository();
    await pumpSignedIn(tester, profile: customerProfile, accountSettings: repo);
    await tester.tap(navLabel('Tài khoản'));
    await tester.pumpAndSettle();
    final row = find.byKey(const ValueKey('account-notif-row'));
    await tester.ensureVisible(row);
    await tester.tap(row);
    await tester.pumpAndSettle();
    expect(find.text('Thông báo của bạn'), findsOneWidget);
    await tester.ensureVisible(find.text('Lưu cài đặt'));
    await tester.tap(find.text('Lưu cài đặt'));
    await tester.pump(); // start _save
    await tester.pump(); // complete futures
    await tester.pumpAndSettle();
    expect(repo.calls, contains('savePrefs'), reason: 'calls=${repo.calls}');
    // Scroll list so success banner is built/visible
    await tester.drag(find.byType(ListView).first, const Offset(0, -400));
    await tester.pumpAndSettle();
    expect(find.text('Đã lưu cài đặt thông báo'), findsOneWidget);
  });

  testWidgets('S028 lists sessions and revokes another device', (tester) async {
    final repo = FakeAccountSettingsRepository();
    await pumpSignedIn(tester, profile: customerProfile, accountSettings: repo);
    await tester.tap(navLabel('Tài khoản'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.byKey(const ValueKey('account-security-row')));
    await tester.tap(find.byKey(const ValueKey('account-security-row')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Thiết bị và phiên đăng nhập'));
    await tester.pumpAndSettle();
    expect(find.text('Phiên hoạt động'), findsOneWidget);
    expect(find.text('MacBook · Safari'), findsOneWidget);
    await tester.tap(find.text('Đăng xuất').last);
    await tester.pumpAndSettle();
    expect(repo.calls, contains('revoke:sess-other'));
  });

  Future<void> openSecurity(WidgetTester tester) async {
    await tester.tap(navLabel('Tài khoản'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.byKey(const ValueKey('account-security-row')));
    await tester.tap(find.byKey(const ValueKey('account-security-row')));
    await tester.pumpAndSettle();
  }

  testWidgets('S025 adds a passkey through the registration endpoints (DEC-PROD-045)', (
    tester,
  ) async {
    final repo = FakeAccountSettingsRepository();
    final passkeys = FakePasskeyPlatform();
    await pumpSignedIn(
      tester,
      profile: customerProfile,
      accountSettings: repo,
      passkeyPlatform: passkeys,
    );
    await openSecurity(tester);
    await tester.tap(find.byKey(const Key('security-passkey-row')));
    await tester.pumpAndSettle();
    expect(repo.calls, containsAllInOrder(['passkeyOptions', 'passkeyVerify']));
    expect(passkeys.registerCalls.single['challenge'], 'fake-challenge');
    expect(find.text('Đã thêm passkey cho tài khoản.'), findsOneWidget);
  });

  testWidgets('S025 explains an unsupported device and never calls verify', (tester) async {
    final repo = FakeAccountSettingsRepository();
    final passkeys = FakePasskeyPlatform()
      ..registerFailure = PasskeyFailureKind.unsupported;
    await pumpSignedIn(
      tester,
      profile: customerProfile,
      accountSettings: repo,
      passkeyPlatform: passkeys,
    );
    await openSecurity(tester);
    await tester.tap(find.byKey(const Key('security-passkey-row')));
    await tester.pumpAndSettle();
    expect(repo.calls, isNot(contains('passkeyVerify')));
    expect(find.textContaining('chưa hỗ trợ passkey'), findsOneWidget);
  });

  testWidgets('S025 shows a calm message when passkey sign-in is turned off', (tester) async {
    final repo = FakeAccountSettingsRepository()
      ..passkeyError = const ApiException(
        statusCode: 403,
        errorCode: 'AUTH_METHOD_DISABLED',
        message: 'Auth method PASSKEY is disabled',
      );
    await pumpSignedIn(tester, profile: customerProfile, accountSettings: repo);
    await openSecurity(tester);
    await tester.tap(find.byKey(const Key('security-passkey-row')));
    await tester.pumpAndSettle();
    expect(find.text('Đăng nhập bằng passkey đang tạm tắt.'), findsOneWidget);
  });
}
