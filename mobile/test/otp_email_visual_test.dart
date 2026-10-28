// Email OTP screen layout on small/large phones, with and without the keyboard.
// PNGs only with --dart-define=SHOT_DIR=/abs/dir.
import 'package:dealgo/core/design_system/theme/dealgo_theme.dart';
import 'package:dealgo/core/network/api_exception.dart';
import 'package:dealgo/features/identity/presentation/widgets/otp_widgets.dart';
import 'package:dealgo/l10n/app_localizations.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/visual_shot.dart';

const _email = 'nguyen.van.an.rat.dai@congty-vidu.com.vn';

Widget _host(Widget pane, {double keyboard = 0}) => MaterialApp(
  debugShowCheckedModeBanner: false,
  theme: DealGoTheme.light,
  locale: const Locale('vi'),
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  supportedLocales: AppLocalizations.supportedLocales,
  home: Builder(
    builder: (context) => MediaQuery(
      data: MediaQuery.of(context)
          .copyWith(viewInsets: EdgeInsets.only(bottom: keyboard)),
      child: Scaffold(
        backgroundColor: Colors.white,
        body: SafeArea(child: pane),
      ),
    ),
  ),
);

OtpEntryPane _entry(
  TextEditingController code, {
  Duration remaining = const Duration(seconds: 42),
}) => OtpEntryPane(
  code: code,
  phone: _email,
  isEmail: true,
  error: null,
  submitting: false,
  resending: false,
  canConfirm: code.text.length == otpCodeLength,
  remaining: remaining,
  onBack: () {},
  onChanged: () {},
  onResend: () {},
  onConfirm: () {},
);

void main() {
  for (final (name, size) in [
    ('se', const Size(375, 667)),
    ('pro', const Size(390, 844)),
  ]) {
    testWidgets('email OTP entry renders without overflow ($name)', (
      tester,
    ) async {
      await loadShotFonts(tester);
      tester.view.physicalSize = size * 2;
      tester.view.devicePixelRatio = 2;
      addTearDown(tester.view.reset);
      final code = TextEditingController(text: '482');
      addTearDown(code.dispose);

      await tester.pumpWidget(_host(_entry(code)));
      await tester.pump(const Duration(milliseconds: 300));
      await saveShot(tester, 'otp-email-entry-$name');
      expect(tester.takeException(), isNull);

      await tester.pumpWidget(_host(_entry(code), keyboard: 300));
      await tester.pump(const Duration(milliseconds: 300));
      await saveShot(tester, 'otp-email-entry-keyboard-$name');
      expect(tester.takeException(), isNull);

      await tester.pumpWidget(_host(_entry(code, remaining: Duration.zero)));
      await tester.pump(const Duration(milliseconds: 300));
      await saveShot(tester, 'otp-email-entry-resend-ready-$name');
      expect(tester.takeException(), isNull);

      await tester.pumpWidget(
        _host(
          OtpCooldownPane(
            phone: _email,
            isEmail: true,
            remaining: const Duration(seconds: 37),
            onBack: () {},
            onLeave: () {},
            onContinue: () {},
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 300));
      await saveShot(tester, 'otp-email-cooldown-$name');
      expect(tester.takeException(), isNull);

      await tester.pumpWidget(
        _host(
          OtpInvalidPane(
            code: '111111',
            isEmail: true,
            error: const ApiException(
              statusCode: 400,
              errorCode: 'AUTH_CODE_INVALID',
              message: 'x',
            ),
            onBack: () {},
            onChangePhone: () {},
            onRetry: () {},
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 300));
      await saveShot(tester, 'otp-email-invalid-$name');
      expect(tester.takeException(), isNull);
    });
  }

  group('OtpCodeField', () {
    test('extracts a standalone 6-digit code from pasted text', () {
      expect(extractOtpCode('Mã xác thực DealGo: 482913'), '482913');
      expect(extractOtpCode('482913'), '482913');
      expect(extractOtpCode('năm 2026, mã 1234567'), isNull);
      expect(extractOtpCode('hello'), isNull);
      const f = OtpCodeInputFormatter();
      TextEditingValue v(String t) => TextEditingValue(text: t);
      expect(f.formatEditUpdate(v(''), v('Mã DealGo: 482913')).text, '482913');
      expect(f.formatEditUpdate(v('48'), v('48a2')).text, '482');
      expect(f.formatEditUpdate(v('48291'), v('4829137')).text, '482913');
    });

    testWidgets('one-time-code autofill hint, auto-submit once on 6 digits', (
      tester,
    ) async {
      final code = TextEditingController();
      addTearDown(code.dispose);
      var completed = 0;
      await tester.pumpWidget(
        _host(
          StatefulBuilder(
            builder: (context, setState) => OtpEntryPane(
              code: code,
              phone: _email,
              isEmail: true,
              error: null,
              submitting: false,
              resending: false,
              canConfirm: code.text.length == otpCodeLength,
              remaining: Duration.zero,
              onBack: () {},
              onChanged: () => setState(() {}),
              onCompleted: () => completed++,
              onResend: () {},
              onConfirm: () {},
            ),
          ),
        ),
      );
      final field = tester.widget<TextField>(
        find.byKey(const Key('otp-field')),
      );
      expect(field.autofillHints, contains(AutofillHints.oneTimeCode));
      expect(field.keyboardType, TextInputType.number);
      expect(find.text('Gửi lại mã sau'), findsNothing);
      expect(
        find.text('Chưa nhận được mã?', findRichText: true),
        findsOneWidget,
      );
      // Header is a back arrow; no duplicate "Đổi email" link.
      expect(find.byKey(const Key('otp-back')), findsOneWidget);
      expect(find.text('Đổi email'), findsNothing);

      await tester.enterText(
        find.byKey(const Key('otp-field')),
        'Mã xác thực DealGo: 482913',
      );
      await tester.pump();
      expect(code.text, '482913');
      expect(completed, 1);
      await tester.enterText(find.byKey(const Key('otp-field')), '482913');
      await tester.pump();
      expect(completed, 1);
    });

    testWidgets('Android: clipboard code shows a one-tap "Dán mã" chip', (
      tester,
    ) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.android;
      const clip = 'Mã xác thực DealGo: 305718';
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        (call) async {
          if (call.method == 'Clipboard.hasStrings') {
            return {'value': true};
          }
          if (call.method == 'Clipboard.getData') {
            return {'text': clip};
          }
          return null;
        },
      );
      addTearDown(() {
        tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          SystemChannels.platform,
          null,
        );
      });
      await loadShotFonts(tester);
      tester.view.physicalSize = const Size(375, 667) * 2;
      tester.view.devicePixelRatio = 2;
      addTearDown(tester.view.reset);
      final code = TextEditingController();
      addTearDown(code.dispose);
      var completed = 0;
      await tester.pumpWidget(
        _host(
          StatefulBuilder(
            builder: (context, setState) => OtpEntryPane(
              code: code,
              phone: _email,
              isEmail: true,
              error: null,
              submitting: false,
              resending: false,
              canConfirm: code.text.length == otpCodeLength,
              remaining: const Duration(seconds: 51),
              onBack: () {},
              onChanged: () => setState(() {}),
              onCompleted: () => completed++,
              onResend: () {},
              onConfirm: () {},
            ),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.byKey(const Key('otp-paste-chip')), findsOneWidget);
      expect(find.text('Dán mã 305718'), findsOneWidget);
      await saveShot(tester, 'otp-email-android-paste-chip');
      await tester.tap(find.byKey(const Key('otp-paste-chip')));
      await tester.pump();
      expect(code.text, '305718');
      expect(completed, 1);
      expect(find.byKey(const Key('otp-paste-chip')), findsNothing);
      await saveShot(tester, 'otp-email-android-pasted');

      // Same code is not offered again after resume.
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pump(const Duration(milliseconds: 100));
      expect(find.byKey(const Key('otp-paste-chip')), findsNothing);
      debugDefaultTargetPlatformOverride = null;
    });

    testWidgets('iOS: no clipboard read (avoids the paste-permission banner)', (
      tester,
    ) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
      var reads = 0;
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        (call) async {
          if (call.method == 'Clipboard.getData') reads++;
          return null;
        },
      );
      addTearDown(() {
        tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          SystemChannels.platform,
          null,
        );
      });
      final code = TextEditingController();
      addTearDown(code.dispose);
      await tester.pumpWidget(_host(_entry(code)));
      await tester.pump(const Duration(milliseconds: 100));
      expect(reads, 0);
      debugDefaultTargetPlatformOverride = null;
    });
  });
}
