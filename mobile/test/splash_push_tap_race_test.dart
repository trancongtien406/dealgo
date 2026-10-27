import 'package:dealgo/core/storage/onboarding_storage.dart';
import 'package:dealgo/features/identity/presentation/pages/splash_page.dart';
import 'package:dealgo/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

GoRouter _router() => GoRouter(
  initialLocation: '/splash',
  routes: [
    GoRoute(
      path: '/splash',
      builder: (_, _) => DealGoSplashScreen(
        minDuration: const Duration(milliseconds: 100),
        storage: MemoryOnboardingStorage(initial: true),
      ),
    ),
    GoRoute(path: '/login', builder: (_, _) => const Text('login')),
    GoRoute(path: '/driver/jobs', builder: (_, _) => const Text('jobs')),
  ],
);

Widget _app(GoRouter router) => MaterialApp.router(
  routerConfig: router,
  locale: const Locale('vi'),
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  supportedLocales: AppLocalizations.supportedLocales,
);

void main() {
  testWidgets(
    'splash timer does not override a cold-start push tap that already '
    'navigated (driver lands on /driver/jobs, not home)',
    (tester) async {
      final router = _router();
      await tester.pumpWidget(_app(router));
      await tester.pump(const Duration(milliseconds: 30));

      // NotificationRouter.flushPending -> router.go(...) before the timer.
      router.go('/driver/jobs');
      await tester.pump(const Duration(milliseconds: 50));
      await tester.pump(const Duration(milliseconds: 200));
      await tester.pumpAndSettle();

      expect(router.state.uri.path, '/driver/jobs');
      expect(find.text('jobs'), findsOneWidget);
    },
  );

  testWidgets('splash still proceeds when nothing navigated', (tester) async {
    final router = _router();
    await tester.pumpWidget(_app(router));
    await tester.pump(const Duration(milliseconds: 200));
    await tester.pumpAndSettle();

    expect(router.state.uri.path, '/login');
  });
}
