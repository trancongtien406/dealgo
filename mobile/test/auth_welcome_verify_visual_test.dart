// Welcome -> email sign-up -> verify-email on small (SE) and large (Pro)
// phones, keyboard closed and open (simulated insets). Fails on any layout
// exception. PNGs only with --dart-define=SHOT_DIR=/abs/dir.
import 'package:dealgo/app/dealgo_app.dart';
import 'package:dealgo/core/auth/post_auth_gate.dart';
import 'package:dealgo/core/network/api_exception.dart';
import 'package:dealgo/features/identity/domain/auth_redirect.dart';
import 'package:dealgo/features/onboarding/data/datasources/partner_requirements_client.dart';
import 'package:dealgo/features/onboarding/presentation/document_image_source.dart';
import 'package:dealgo/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/fake_food_client.dart';
import 'support/fake_identity_client.dart';
import 'support/fake_location.dart';
import 'support/fake_ride_client.dart';
import 'support/memory_token_store.dart';
import 'support/visual_shot.dart';

const _email = 'nguyen.van.an.rat.dai@congty-vidu.com.vn';
const _shotKey = Key('t88-shot');

typedef _Phone = ({
  String name,
  Size size,
  double top,
  double bottom,
  double keyboard,
});

const List<_Phone> _phones = [
  (name: 'se', size: Size(375, 667), top: 20, bottom: 0, keyboard: 260),
  (name: 'pro', size: Size(402, 874), top: 62, bottom: 34, keyboard: 336),
];

void main() {
  for (final phone in _phones) {
    testWidgets('welcome -> email -> verify email lays out (${phone.name})', (
      tester,
    ) async {
      await loadShotFonts(tester);
      const dpr = 3.0;
      tester.view.physicalSize = phone.size * dpr;
      tester.view.devicePixelRatio = dpr;
      tester.view.padding = FakeViewPadding(
        top: phone.top * dpr,
        bottom: phone.bottom * dpr,
      );
      addTearDown(tester.view.reset);

      final errors = <String>[];
      Future<void> shot(String name, {bool keyboard = false}) async {
        tester.view.viewInsets = FakeViewPadding(
          bottom: keyboard ? phone.keyboard * dpr : 0,
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 400));
        final error = tester.takeException();
        if (error != null) {
          errors.add('$name: $error');
        }
        await saveShot(
          tester,
          '${phone.name}-$name',
          finder: find.byKey(_shotKey),
        );
      }

      AppLocalizations l10n() =>
          AppLocalizations.of(tester.element(find.byType(Scaffold).last));

      final client = FakeIdentityClient();
      await tester.pumpWidget(
        RepaintBoundary(
          key: _shotKey,
          child: DealGoApp(
            identityClient: client,
            tokenStore: MemoryTokenStore(),
            foodClient: FakeFoodClient(),
            rideClient: FakeRideClient(),
            documentImageSource: FakeDocumentImageSource(),
            partnerRequirements: const FixedPartnerRequirements(),
            locationOverride: FakeLocationService(),
            postAuthGate: PostAuthGate.seeded(),
            initialLocation: AuthRoutes.login,
          ),
        ),
      );
      await tester.pumpAndSettle();
      await shot('01-welcome');

      await tester.tap(find.byKey(const Key('auth-method-email')));
      await tester.pumpAndSettle();
      await shot('02-email-login');
      await shot('03-email-login-kb', keyboard: true);

      await tester.tap(find.byKey(const Key('email-tab-register')));
      await tester.pumpAndSettle();
      await tester.enterText(find.byKey(const Key('email-field')), _email);
      await tester.enterText(
        find.byKey(const Key('password-field')),
        'matkhau123',
      );
      await tester.enterText(
        find.byKey(const Key('confirm-password-field')),
        'matkhau123',
      );
      await shot('04-email-register');
      await shot('05-email-register-kb', keyboard: true);

      tester.view.viewInsets = FakeViewPadding.zero;
      final submit = find.byKey(const Key('email-submit-btn'));
      await tester.ensureVisible(submit);
      await tester.pumpAndSettle();
      await tester.tap(submit);
      for (var i = 0; i < 6; i++) {
        await tester.pump(const Duration(milliseconds: 250));
      }
      expect(find.byKey(const Key('otp-field')), findsOneWidget);
      await shot('06-otp-kb', keyboard: true);
      await tester.enterText(find.byKey(const Key('otp-field')), '482');
      await shot('07-otp-partial-kb', keyboard: true);
      await shot('08-otp-partial');

      await tester.ensureVisible(find.byKey(const Key('otp-resend')));
      await tester.tap(find.byKey(const Key('otp-resend')));
      await shot('09-otp-cooldown');
      await tester.tap(find.text(l10n().actionKeepEnteringCode));
      await tester.pump();

      client.emailVerifyError = const ApiException(
        statusCode: 400,
        errorCode: 'AUTH_CODE_INVALID',
        message: 'Verification code is invalid',
      );
      await tester.enterText(find.byKey(const Key('otp-field')), '111111');
      await tester.pump(const Duration(milliseconds: 300));
      await shot('10-otp-invalid');
      await tester.tap(find.text(l10n().actionRetry));
      await shot('11-otp-retry-kb', keyboard: true);

      expect(errors, isEmpty, reason: errors.join('\n'));
    });
  }
}
