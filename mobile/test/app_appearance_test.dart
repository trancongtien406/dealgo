import 'package:dealgo/core/appearance/app_appearance.dart';
import 'package:dealgo/core/auth/token_store.dart';
import 'package:dealgo/core/design_system/tokens/dealgo_tokens.dart';
import 'package:dealgo/features/identity/data/repositories/identity_repository_impl.dart';
import 'package:dealgo/features/identity/domain/usecases/fetch_me.dart';
import 'package:dealgo/features/identity/presentation/cubit/auth_cubit.dart';
import 'package:dealgo/features/shell/presentation/account_page.dart';
import 'package:dealgo/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'support/fake_identity_client.dart';
import 'support/test_l10n.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    AppAppearance.resetForTest();
  });

  tearDown(AppAppearance.resetForTest);

  test('no saved choice is Vietnamese and light', () async {
    await AppAppearance.warmUp();
    final appearance = AppAppearance.fromWarmup();
    expect(appearance.locale.languageCode, 'vi');
    expect(appearance.themeChoice, AppThemeChoice.light);
    expect(appearance.themeMode, ThemeMode.light);
    expect(appearance.brightness(Brightness.dark), Brightness.light);
    expect(appearance.brightness(Brightness.light), Brightness.light);
    appearance.applyPalette(Brightness.dark);
    expect(DealGoColors.canvas, DealGoPalette.light.canvas);
  });

  test('saved language and theme win over the defaults', () async {
    SharedPreferences.setMockInitialValues({
      AppAppearance.localeKey: 'en',
      AppAppearance.themeKey: 'dark',
    });
    await AppAppearance.warmUp();
    final appearance = AppAppearance.fromWarmup();
    expect(appearance.locale, const Locale('en'));
    expect(appearance.themeChoice, AppThemeChoice.dark);
    expect(appearance.themeMode, ThemeMode.dark);
    expect(appearance.brightness(Brightness.light), Brightness.dark);

    await appearance.setLocale(const Locale('fr'));
    expect(appearance.locale.languageCode, 'vi');
    await appearance.setTheme(AppThemeChoice.light);
    await AppAppearance.warmUp();
    final again = AppAppearance.fromWarmup();
    expect(again.locale.languageCode, 'vi');
    expect(again.themeChoice, AppThemeChoice.light);
  });

  testWidgets('account page can switch language and appearance', (
    tester,
  ) async {
    final appearance = AppAppearance();
    final auth = AuthCubit(
      fetchMe: FetchMe(IdentityRepositoryImpl(FakeIdentityClient())),
      tokens: MemoryTokenStore(),
    );
    addTearDown(auth.close);

    Future<void> pump() {
      return tester.pumpWidget(
        ChangeNotifierProvider<AppAppearance>.value(
          value: appearance,
          child: BlocProvider<AuthCubit>.value(
            value: auth,
            child: MaterialApp(
              locale: appearance.locale,
              localizationsDelegates: testLocalizationsDelegates,
              supportedLocales: AppLocalizations.supportedLocales,
              home: const AccountPage(shellPath: '/customer'),
            ),
          ),
        ),
      );
    }

    await pump();
    final language = find.byKey(const Key('account-language'));
    await tester.scrollUntilVisible(language, 200);
    expect(find.text('Hiển thị'), findsOneWidget);
    expect(find.text('Ngôn ngữ'), findsOneWidget);
    expect(find.text('Tiếng Việt'), findsOneWidget);
    expect(find.text('Sáng'), findsOneWidget);

    await tester.tap(language);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('appearance-locale-en')));
    await tester.pumpAndSettle();
    expect(appearance.locale.languageCode, 'en');

    await pump();
    expect(find.text('Language'), findsOneWidget);
    expect(find.text('English'), findsOneWidget);

    final theme = find.byKey(const Key('account-theme'));
    await tester.scrollUntilVisible(theme, 200);
    await tester.tap(theme);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('appearance-theme-dark')));
    await tester.pumpAndSettle();
    expect(appearance.themeChoice, AppThemeChoice.dark);
  });
}
