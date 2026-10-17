import 'package:dealgo/core/design_system/components/dealgo_logo.dart';
import 'package:dealgo/core/storage/onboarding_storage.dart';
import 'package:dealgo/features/identity/presentation/pages/splash_page.dart';
import 'package:dealgo/features/onboarding/presentation/pages/customer_onboarding_page.dart';
import 'package:dealgo/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _wrap(Widget child) {
  return MaterialApp(
    localizationsDelegates: const [
      AppLocalizations.delegate,
      GlobalMaterialLocalizations.delegate,
      GlobalWidgetsLocalizations.delegate,
      GlobalCupertinoLocalizations.delegate,
    ],
    supportedLocales: AppLocalizations.supportedLocales,
    locale: const Locale('vi'),
    home: child,
  );
}

void main() {
  group('DealGoLogo Component', () {
    testWidgets('renders wordmark with Deal and Go', (tester) async {
      await tester.pumpWidget(_wrap(const DealGoLogo.wordmark()));
      expect(find.byType(DealGoLogo), findsOneWidget);
      expect(find.text('DealGo', findRichText: true), findsOneWidget);
    });

    testWidgets('renders stacked logo with slogan', (tester) async {
      await tester.pumpWidget(
        _wrap(const DealGoLogo.stacked(subtitle: 'Đi muôn nơi · Ăn vạn món')),
      );
      expect(find.text('Đi muôn nơi · Ăn vạn món'), findsOneWidget);
    });
  });

  group('S001 DealGoSplashScreen', () {
    testWidgets('renders brand slogan and floating service highlights', (tester) async {
      await tester.pumpWidget(_wrap(const DealGoSplashScreen(autoNavigate: false)));
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.text('Đi muôn nơi · Ăn vạn món'), findsOneWidget);
      expect(find.text('Đặt xe'), findsOneWidget);
      expect(find.text('Đồ ăn'), findsOneWidget);
      expect(find.text('Đang chuẩn bị trải nghiệm của bạn...'), findsOneWidget);
    });
  });

  group('S002 CustomerOnboardingPage', () {
    testWidgets('renders initial slide and allows advancing through steps', (tester) async {
      var completed = false;
      final storage = MemoryOnboardingStorage();
      await tester.pumpWidget(
        _wrap(CustomerOnboardingPage(
          onComplete: () => completed = true,
          storage: storage,
        )),
      );
      await tester.pumpAndSettle();

      // Step 1 check
      expect(find.text('Bỏ qua'), findsOneWidget);
      expect(find.text('Một ứng dụng,\nvạn trải nghiệm', findRichText: true), findsOneWidget);
      expect(find.text('Bước 1 trong 3'), findsOneWidget);

      // Tap Next to step 2
      await tester.tap(find.byKey(const Key('onboarding-next-btn')));
      await tester.pumpAndSettle();

      expect(find.text('Bước 2 trong 3'), findsOneWidget);
      expect(find.text('Di chuyển nhanh,\nan toàn & tiết kiệm', findRichText: true), findsOneWidget);

      // Tap Next to step 3
      await tester.tap(find.byKey(const Key('onboarding-next-btn')));
      await tester.pumpAndSettle();

      expect(find.text('Bước 3 trong 3'), findsOneWidget);
      expect(find.text('Bắt đầu ngay'), findsOneWidget);

      // Tap Finish
      await tester.tap(find.byKey(const Key('onboarding-next-btn')));
      await tester.pumpAndSettle();

      expect(completed, isTrue);
      expect(await storage.hasSeenOnboarding(), isTrue);
    });

    testWidgets('tapping Bỏ qua triggers completion directly', (tester) async {
      var completed = false;
      final storage = MemoryOnboardingStorage();
      await tester.pumpWidget(
        _wrap(CustomerOnboardingPage(
          onComplete: () => completed = true,
          storage: storage,
        )),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Bỏ qua'));
      await tester.pumpAndSettle();

      expect(completed, isTrue);
      expect(await storage.hasSeenOnboarding(), isTrue);
    });
  });
}
