import 'package:dealgo/core/design_system/theme/dealgo_theme.dart';
import 'package:dealgo/core/navigation/external_navigator.dart';
import 'package:dealgo/features/driver/presentation/widgets/driver_navigate_buttons.dart';
import 'package:dealgo/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'support/fake_external_navigator.dart';
import 'support/test_l10n.dart';

Future<void> _pump(WidgetTester tester, FakeExternalNavigator nav) async {
  await tester.pumpWidget(
    RepositoryProvider<ExternalNavigator>.value(
      value: nav,
      child: MaterialApp(
        theme: DealGoTheme.light,
        localizationsDelegates: testLocalizationsDelegates,
        locale: testLocale,
        supportedLocales: AppLocalizations.supportedLocales,
        home: const Scaffold(
          body: Center(
            child: DriverNavigateButtons(
              lat: 16.06,
              lng: 108.22,
              destinationLabel: 'Đến điểm đón khách',
              platform: TargetPlatform.iOS,
            ),
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    DriverNavigateButtons.resetLastChoice();
  });

  testWidgets('one Điều hướng button opens a sheet with installed apps only', (
    tester,
  ) async {
    final nav = FakeExternalNavigator(installed: {NavigationApp.waze});
    await _pump(tester, nav);
    expect(find.text('Điều hướng'), findsOneWidget);
    expect(find.byKey(const Key('driver-nav-google')), findsNothing);

    await tester.tap(find.byKey(const Key('driver-nav-open')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('driver-nav-sheet')), findsOneWidget);
    expect(find.text('Chỉ đường bằng'), findsOneWidget);
    expect(find.text('Đến điểm đón khách'), findsOneWidget);
    // Google Maps not installed → hidden; web fallback always there.
    expect(find.byKey(const Key('driver-nav-google')), findsNothing);
    expect(find.byKey(const Key('driver-nav-waze')), findsOneWidget);
    expect(find.byKey(const Key('driver-nav-web')), findsOneWidget);

    await tester.tap(find.byKey(const Key('driver-nav-web')));
    await tester.pumpAndSettle();
    expect(nav.calls, [(NavigationApp.web, 16.06, 108.22)]);
    expect(find.byKey(const Key('driver-nav-sheet')), findsNothing);
  });

  testWidgets('the last pick is listed first with a "Lần trước" chip', (
    tester,
  ) async {
    final nav = FakeExternalNavigator();
    await _pump(tester, nav);
    await tester.tap(find.byKey(const Key('driver-nav-open')));
    await tester.pumpAndSettle();
    expect(find.text('Lần trước'), findsNothing);
    await tester.tap(find.byKey(const Key('driver-nav-waze')));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('driver-nav-open')));
    await tester.pumpAndSettle();
    expect(find.text('Lần trước'), findsOneWidget);
    final wazeY = tester
        .getTopLeft(find.byKey(const Key('driver-nav-waze')))
        .dy;
    final googleY = tester
        .getTopLeft(find.byKey(const Key('driver-nav-google')))
        .dy;
    expect(wazeY, lessThan(googleY));
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString('driver.nav.lastApp'), 'waze');
  });
}
