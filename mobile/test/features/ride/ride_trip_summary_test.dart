import 'package:dealgo/features/ride/presentation/widgets/ride_widgets.dart';
import 'package:dealgo/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _host(Widget child) => MaterialApp(
  locale: const Locale('vi'),
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  supportedLocales: AppLocalizations.supportedLocales,
  home: Scaffold(body: Center(child: child)),
);

void main() {
  testWidgets('shows server km and minutes', (tester) async {
    await tester.pumpWidget(
      _host(const RideTripSummary(distanceKm: 5.2, durationMin: 14)),
    );
    expect(find.text('5,2 km'), findsOneWidget);
    expect(find.text('14 phút'), findsOneWidget);
  });

  testWidgets('renders nothing without route data', (tester) async {
    await tester.pumpWidget(
      _host(const RideTripSummary(distanceKm: null, durationMin: 0)),
    );
    expect(find.byKey(const Key('ride-trip-summary')), findsNothing);
  });
}
