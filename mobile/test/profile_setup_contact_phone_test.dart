import 'package:dealgo/core/auth/post_auth_gate.dart';
import 'package:dealgo/core/auth/token_store.dart';
import 'package:dealgo/core/permissions/app_permission_service.dart';
import 'package:dealgo/features/identity/data/repositories/identity_repository_impl.dart';
import 'package:dealgo/features/identity/domain/entities/user_profile.dart';
import 'package:dealgo/features/identity/domain/phone_input.dart';
import 'package:dealgo/features/identity/domain/repositories/identity_repository.dart';
import 'package:dealgo/features/identity/domain/usecases/fetch_me.dart';
import 'package:dealgo/features/identity/presentation/cubit/auth_cubit.dart';
import 'package:dealgo/features/onboarding/presentation/pages/profile_setup_page.dart';
import 'package:dealgo/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'support/fake_identity_client.dart';
import 'support/fake_permission_service.dart';
import 'support/test_l10n.dart';

Future<FakeIdentityClient> _pump(WidgetTester tester, {String? phone}) async {
  final client = FakeIdentityClient(
    profile: UserProfile(
      id: 'u-new',
      phone: phone,
      email: 'new@dealgo.test',
      phoneVerifiedAt: null,
      emailVerifiedAt: '2026-10-29T00:00:00.000Z',
      displayName: 'DealGo user',
      needsProfileSetup: true,
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
  final service = FakeAppPermissionService();
  await tester.pumpWidget(
    ChangeNotifierProvider<PostAuthGate>.value(
      value: gate,
      child: MultiRepositoryProvider(
        providers: [
          RepositoryProvider<AppPermissionService>.value(value: service),
          RepositoryProvider<IdentityRepository>.value(value: repository),
        ],
        child: BlocProvider<AuthCubit>.value(
          value: auth,
          child: MaterialApp(
            localizationsDelegates: testLocalizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            locale: testLocale,
            home: ProfileSetupPage(permissionService: service),
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return client;
}

void main() {
  test('vnMobileFromInput accepts assigned VN mobile prefixes only', () {
    expect(vnMobileFromInput('0901 234 567'), '+84901234567');
    expect(vnMobileFromInput('901234567'), '+84901234567');
    expect(vnMobileFromInput('84901234567'), '+84901234567');
    expect(vnMobileFromInput('+84 389 999 999'), '+84389999999');
    expect(vnMobileFromInput('0321234567'), '+84321234567');
    expect(vnMobileFromInput('0551234567'), '+84551234567');
    expect(vnMobileFromInput('0871234567'), '+84871234567');
    expect(vnMobileFromInput('0991234567'), '+84991234567');
    expect(vnMobileFromInput('0241234567'), isNull);
    expect(vnMobileFromInput('0301234567'), isNull);
    expect(vnMobileFromInput('0712345678'), isNull);
    expect(vnMobileFromInput('0801234567'), isNull);
    expect(vnMobileFromInput('0951234567'), isNull);
    expect(vnMobileFromInput('+840901234567'), isNull);
    expect(vnMobileFromInput('09012345'), isNull);
    expect(vnMobileFromInput('+14155550100'), isNull);
    expect(vnMobileFromInput(''), isNull);
  });

  testWidgets(
    'email/passkey account must type a phone (no OTP) and it is saved',
    (tester) async {
      final client = await _pump(tester);
      expect(find.text('Số điện thoại'), findsWidgets);
      expect(find.byKey(const Key('phone-field')), findsOneWidget);

      await tester.enterText(find.byKey(const Key('name-field')), 'Lan Anh');
      await tester.pump();
      FilledButton done() => tester.widget<FilledButton>(
        find.ancestor(
          of: find.text('Hoàn tất'),
          matching: find.byType(FilledButton),
        ),
      );
      expect(done().enabled, isFalse, reason: 'phone still empty');

      await tester.enterText(
        find.byKey(const Key('phone-field')),
        '024 123 4567',
      );
      await tester.pump();
      await tester.tap(find.text('Hoàn tất'));
      await tester.pumpAndSettle();
      expect(
        find.textContaining('Số di động Việt Nam không hợp lệ'),
        findsOneWidget,
      );
      expect(client.updateMeCalls, isEmpty);

      await tester.enterText(
        find.byKey(const Key('phone-field')),
        '0901 234 567',
      );
      await tester.pump();
      await tester.tap(find.text('Hoàn tất'));
      await tester.pump(const Duration(milliseconds: 300));
      expect(client.updateMeCalls.single['contactPhone'], '+84901234567');
      expect(client.updateMeCalls.single['displayName'], 'Lan Anh');
      expect(client.profile.needsProfileSetup, isFalse);
    },
  );

  testWidgets('phone-OTP account is not asked for a phone again', (
    tester,
  ) async {
    await _pump(tester, phone: '+84911111111');
    expect(find.byKey(const Key('phone-field')), findsNothing);
  });
}
