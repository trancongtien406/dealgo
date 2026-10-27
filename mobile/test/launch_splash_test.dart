import 'package:dealgo/core/auth/token_store.dart';
import 'package:dealgo/core/design_system/tokens/dealgo_tokens.dart';
import 'package:dealgo/core/launch/launch_splash.dart';
import 'package:dealgo/core/storage/onboarding_storage.dart';
import 'package:dealgo/features/identity/data/datasources/dio_identity_remote_datasource.dart';
import 'package:dealgo/features/identity/data/repositories/identity_repository_impl.dart';
import 'package:dealgo/features/identity/domain/auth_redirect.dart';
import 'package:dealgo/features/identity/domain/entities/auth_state.dart';
import 'package:dealgo/features/identity/domain/usecases/fetch_me.dart';
import 'package:dealgo/features/identity/presentation/cubit/auth_cubit.dart';
import 'package:dealgo/features/identity/presentation/pages/splash_page.dart';
import 'package:dealgo/l10n/app_localizations.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

AuthCubit _signedOutOnRestore() => AuthCubit(
  fetchMe: FetchMe(
    IdentityRepositoryImpl(DioIdentityRemoteDataSource(dio: Dio())),
  ),
  tokens: MemoryTokenStore(),
);

GoRouter _router({required bool seenOnboarding, Duration? authTimeout}) =>
    GoRouter(
      initialLocation: AuthRoutes.splash,
      routes: [
        GoRoute(
          path: AuthRoutes.splash,
          builder: (_, _) => DealGoSplashScreen(
            storage: MemoryOnboardingStorage(initial: seenOnboarding),
            authTimeout: authTimeout ?? const Duration(seconds: 6),
          ),
        ),
        GoRoute(path: AuthRoutes.login, builder: (_, _) => const Text('login')),
        GoRoute(
          path: AuthRoutes.onboarding,
          builder: (_, _) => const Text('onboarding'),
        ),
      ],
    );

Widget _app(GoRouter router, {AuthCubit? auth}) {
  final app = MaterialApp.router(
    routerConfig: router,
    locale: const Locale('vi'),
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
  );
  return auth == null ? app : BlocProvider.value(value: auth, child: app);
}

void main() {
  group('launchRouteReady', () {
    test('waits for session restore', () {
      expect(
        launchRouteReady(
          auth: const AuthRestoring(),
          postAuthLoaded: true,
          location: AuthRoutes.login,
        ),
        isFalse,
      );
    });

    test('waits for post-auth flags', () {
      expect(
        launchRouteReady(
          auth: const AuthSignedOut(),
          postAuthLoaded: false,
          location: AuthRoutes.login,
        ),
        isFalse,
      );
    });

    test('waits while the router is still on /splash', () {
      expect(
        launchRouteReady(
          auth: const AuthSignedOut(),
          postAuthLoaded: true,
          location: AuthRoutes.splash,
        ),
        isFalse,
      );
    });

    test('ready once restore is done and the first page is chosen', () {
      expect(
        launchRouteReady(
          auth: const AuthSignedOut(),
          postAuthLoaded: true,
          location: AuthRoutes.login,
        ),
        isTrue,
      );
      // Cold-start deep link straight to a page.
      expect(
        launchRouteReady(
          auth: const AuthSignedOut(),
          postAuthLoaded: true,
          location: '/customer/orders/abc',
        ),
        isTrue,
      );
    });
  });

  group('LaunchSplash', () {
    testWidgets('release without hold is a no-op', (tester) async {
      expect(LaunchSplash.isHeld, isFalse);
      LaunchSplash.release();
      expect(LaunchSplash.isHeld, isFalse);
    });

    testWidgets('hold is released by the timeout so launch never hangs', (
      tester,
    ) async {
      LaunchSplash.hold(timeout: const Duration(milliseconds: 500));
      expect(LaunchSplash.isHeld, isTrue);
      await tester.pump(const Duration(milliseconds: 499));
      expect(LaunchSplash.isHeld, isTrue);
      await tester.pump(const Duration(milliseconds: 2));
      expect(LaunchSplash.isHeld, isFalse);
    });

    testWidgets('explicit release ends the hold once', (tester) async {
      LaunchSplash.hold();
      LaunchSplash.release();
      LaunchSplash.release();
      expect(LaunchSplash.isHeld, isFalse);
      await tester.pump(LaunchSplash.defaultTimeout);
      expect(LaunchSplash.isHeld, isFalse);
    });
  });

  group('DealGoSplashScreen', () {
    testWidgets('matches the native launch screen: brand colour + mark only', (
      tester,
    ) async {
      final router = _router(seenOnboarding: true);
      await tester.pumpWidget(_app(router, auth: _signedOutOnRestore()));

      final box = tester.widget<ColoredBox>(
        find.byKey(const Key('dealgo-launch-screen')),
      );
      expect(box.color, DealGoColors.primary);
      final image = tester.widget<Image>(find.byType(Image));
      expect((image.image as AssetImage).assetName, dealGoLaunchMarkAsset);
      expect(image.width, dealGoLaunchMarkSize);
      expect(find.byType(CircularProgressIndicator), findsNothing);
      expect(find.byType(LinearProgressIndicator), findsNothing);
      await tester.pump(const Duration(seconds: 7)); // drain auth timeout
    });

    testWidgets('dark mode uses the deep brand purple', (tester) async {
      tester.platformDispatcher.platformBrightnessTestValue = Brightness.dark;
      addTearDown(tester.platformDispatcher.clearPlatformBrightnessTestValue);
      final router = _router(seenOnboarding: true);
      await tester.pumpWidget(_app(router, auth: _signedOutOnRestore()));

      final box = tester.widget<ColoredBox>(
        find.byKey(const Key('dealgo-launch-screen')),
      );
      expect(box.color, DealGoColors.primaryDeep);
      await tester.pump(const Duration(seconds: 7)); // drain auth timeout
    });

    testWidgets('stays put while the session restores, then routes at once', (
      tester,
    ) async {
      final auth = _signedOutOnRestore();
      final router = _router(seenOnboarding: true);
      await tester.pumpWidget(_app(router, auth: auth));
      await tester.pump(const Duration(seconds: 2));
      expect(router.state.uri.path, AuthRoutes.splash);

      await auth.restore();
      await tester.pumpAndSettle();
      expect(auth.state, isA<AuthSignedOut>());
      expect(router.state.uri.path, AuthRoutes.login);
    });

    testWidgets('first launch goes to onboarding with no artificial delay', (
      tester,
    ) async {
      final router = _router(seenOnboarding: false);
      await tester.pumpWidget(_app(router));
      await tester.pumpAndSettle();
      expect(router.state.uri.path, AuthRoutes.onboarding);
    });

    testWidgets('a restore that never finishes cannot trap the user', (
      tester,
    ) async {
      final router = _router(
        seenOnboarding: true,
        authTimeout: const Duration(seconds: 1),
      );
      await tester.pumpWidget(_app(router, auth: _signedOutOnRestore()));
      await tester.pump(const Duration(milliseconds: 1100));
      await tester.pumpAndSettle();
      expect(router.state.uri.path, AuthRoutes.login);
    });
  });
}
