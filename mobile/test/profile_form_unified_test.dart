import 'package:dealgo/core/auth/post_auth_gate.dart';
import 'package:dealgo/core/auth/token_store.dart';
import 'package:dealgo/core/permissions/app_permission_service.dart';
import 'package:dealgo/features/account_settings/presentation/edit_profile_page.dart';
import 'package:dealgo/features/identity/data/repositories/identity_repository_impl.dart';
import 'package:dealgo/features/identity/domain/entities/user_profile.dart';
import 'package:dealgo/features/identity/domain/phone_input.dart';
import 'package:dealgo/features/identity/domain/repositories/identity_repository.dart';
import 'package:dealgo/features/identity/domain/usecases/fetch_me.dart';
import 'package:dealgo/features/identity/presentation/cubit/auth_cubit.dart';
import 'package:dealgo/features/identity/presentation/widgets/profile_form.dart';
import 'package:dealgo/features/onboarding/presentation/pages/profile_setup_page.dart';
import 'package:dealgo/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'support/fake_identity_client.dart';
import 'support/fake_permission_service.dart';
import 'support/test_l10n.dart';

Future<FakeIdentityClient> _pump(
  WidgetTester tester,
  Widget page, {
  String? phone,
  String? contactPhone,
}) async {
  final client = FakeIdentityClient(
    profile: UserProfile(
      id: 'u-1',
      phone: phone,
      contactPhone: contactPhone,
      email: 'lan@dealgo.test',
      phoneVerifiedAt: null,
      emailVerifiedAt: null,
      displayName: 'Lan Anh',
      gender: UserGender.female,
      dateOfBirth: '1995-04-02',
      needsProfileSetup: false,
      grants: customerProfile.grants,
    ),
  );
  final repository = IdentityRepositoryImpl(client);
  final gate = PostAuthGate.seeded();
  final auth = AuthCubit(
    fetchMe: FetchMe(repository),
    tokens: MemoryTokenStore(),
    identityRepository: repository,
    postAuth: gate,
  );
  await auth.completeSignIn(
    const StoredTokens(accessToken: 'a', refreshToken: 'r'),
  );
  await tester.pumpWidget(
    ChangeNotifierProvider<PostAuthGate>.value(
      value: gate,
      child: MultiRepositoryProvider(
        providers: [
          RepositoryProvider<AppPermissionService>.value(
            value: FakeAppPermissionService(),
          ),
          RepositoryProvider<IdentityRepository>.value(value: repository),
        ],
        child: BlocProvider<AuthCubit>.value(
          value: auth,
          child: MaterialApp(
            localizationsDelegates: testLocalizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            locale: testLocale,
            home: page,
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return client;
}

void main() {
  test('displayVnPhone formats E.164 for the input', () {
    expect(displayVnPhone('+84901234567'), '0901 234 567');
    expect(displayVnPhone(null), '');
  });

  for (final (name, page) in [
    ('complete', const ProfileSetupPage()),
    ('edit', const EditProfilePage()),
  ]) {
    testWidgets('$name profile renders the shared form with all fields', (
      tester,
    ) async {
      await _pump(tester, page, contactPhone: '+84901234567');
      expect(find.byType(ProfileForm), findsOneWidget);
      expect(find.byKey(const Key('avatar-picker')), findsOneWidget);
      expect(find.byKey(const Key('name-field')), findsOneWidget);
      expect(find.byKey(const Key('phone-field')), findsOneWidget);
      expect(find.byKey(const Key('email-field')), findsOneWidget);
      expect(find.text('Ngày sinh (tuỳ chọn)'), findsWidgets);
      expect(find.text('Giới tính'), findsOneWidget);
      // No explanatory helper under the phone input.
      expect(find.textContaining('Không cần mã xác minh'), findsNothing);
      expect(find.textContaining('không đổi tại đây'), findsNothing);
      expect(find.textContaining('không hợp lệ'), findsNothing);
    });
  }

  testWidgets('edit: invalid contact phone shows error only after submit, '
      'valid one is saved', (tester) async {
    final client = await _pump(
      tester,
      const EditProfilePage(),
      contactPhone: '+84901234567',
    );
    await tester.enterText(find.byKey(const Key('phone-field')), '024 123');
    await tester.pump();
    expect(find.textContaining('không hợp lệ'), findsNothing);
    await tester.tap(find.text('Lưu thay đổi'));
    await tester.pumpAndSettle();
    expect(find.textContaining('không hợp lệ'), findsOneWidget);
    expect(client.updateMeCalls, isEmpty);

    await tester.enterText(
      find.byKey(const Key('phone-field')),
      '0389 999 999',
    );
    await tester.pump();
    expect(find.textContaining('không hợp lệ'), findsNothing);
    await tester.tap(find.text('Lưu thay đổi'));
    await tester.pumpAndSettle();
    expect(client.updateMeCalls.single['contactPhone'], '+84389999999');
    expect(client.updateMeCalls.single['gender'], UserGender.female);
  });

  testWidgets('edit: verified login phone is read-only', (tester) async {
    await _pump(tester, const EditProfilePage(), phone: '+84911111111');
    expect(find.byKey(const Key('phone-field')), findsNothing);
    expect(find.byKey(const Key('locked-phone-field')), findsOneWidget);
    expect(find.text('0911 111 111'), findsOneWidget);
  });

  // The OTP field animates its caret forever, so pumpAndSettle never settles
  // while the sheet is open.
  Future<void> pumpSheet(WidgetTester tester) async {
    for (var i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
  }

  Future<void> enterEmailCode(WidgetTester tester, String code) async {
    await tester.enterText(
      find.descendant(
        of: find.byKey(const Key('email-verify-code')),
        matching: find.byType(EditableText),
      ),
      code,
    );
    await pumpSheet(tester);
  }

  testWidgets('edit: saving the current unverified email mails nothing; '
      'Verify asks for the 6-digit code', (tester) async {
    final client = await _pump(
      tester,
      const EditProfilePage(),
      contactPhone: '+84901234567',
    );
    await tester.tap(find.text('Lưu thay đổi'));
    await tester.pumpAndSettle();
    expect(client.updateMeCalls.single['email'], 'lan@dealgo.test');
    expect(client.emailVerificationRequests, isEmpty);
    expect(find.byKey(const Key('email-verify-code')), findsNothing);

    await tester.tap(find.byKey(const Key('email-verify-action')));
    await pumpSheet(tester);
    expect(client.emailVerificationRequests, ['lan@dealgo.test']);
    expect(find.text('lan@dealgo.test'), findsWidgets);

    await enterEmailCode(tester, FakeIdentityClient.emailVerificationCode);
    expect(find.byKey(const Key('email-verify-code')), findsNothing);
    // Queued behind the "profile saved" snack bar from the earlier save.
    await tester.pump(const Duration(seconds: 5));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('email-verified-snack')), findsOneWidget);
    expect(client.profile.emailVerifiedAt, isNotNull);
    expect(find.byKey(const Key('email-verify-action')), findsNothing);
  });

  testWidgets('edit: a new email is applied only after the right code', (
    tester,
  ) async {
    final client = await _pump(
      tester,
      const EditProfilePage(),
      contactPhone: '+84901234567',
    );
    await tester.enterText(
      find.byKey(const Key('email-field')),
      'Lan.New@dealgo.test',
    );
    await tester.pump();
    expect(find.byKey(const Key('email-verify-action')), findsNothing);
    await tester.tap(find.text('Lưu thay đổi'));
    await pumpSheet(tester);

    expect(client.emailVerificationRequests, ['lan.new@dealgo.test']);
    expect(client.profile.email, 'lan@dealgo.test');
    expect(find.byKey(const Key('email-verify-code')), findsOneWidget);

    await enterEmailCode(tester, '000000');
    expect(find.byKey(const Key('email-verify-error')), findsOneWidget);
    expect(client.profile.email, 'lan@dealgo.test');

    await enterEmailCode(tester, FakeIdentityClient.emailVerificationCode);
    expect(find.byKey(const Key('email-verify-code')), findsNothing);
    expect(client.profile.email, 'lan.new@dealgo.test');
    expect(client.profile.emailVerifiedAt, isNotNull);
    expect(client.emailVerificationRequests, hasLength(1));
  });
}
