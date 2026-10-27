import 'dart:io';

import 'package:dealgo/features/shell/presentation/home_services.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/test_l10n.dart';

void main() {
  test('home has one Ride entry: no QuickBookCard, no ride hero slide', () {
    final home = File('lib/features/shell/presentation/customer_home_page.dart')
        .readAsStringSync();
    final hero = File('lib/features/shell/presentation/home_hero.dart')
        .readAsStringSync();
    expect(home.contains('QuickBookCard('), isFalse);
    expect(hero.contains('l10n.rideBookTitle'), isFalse);
    expect(hero.contains('l10n.actionBookRideNow'), isFalse);
  });

  test('offers list carries no long caption', () {
    final src = File(
      'lib/features/ride/presentation/widgets/ride_offers_widgets.dart',
    ).readAsStringSync();
    expect(src.contains('rideOffersNote'), isFalse);
  });

  testWidgets('service row shows exactly one "Đặt xe" plus Food', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('vi'),
        localizationsDelegates: testLocalizationsDelegates,
        supportedLocales: const [Locale('vi'), Locale('en')],
        home: Scaffold(
          body: ServiceRow(onRide: () {}, onFood: () {}),
        ),
      ),
    );
    expect(find.text('Đặt xe'), findsOneWidget);
    expect(find.byKey(const Key('home-service-ride')), findsOneWidget);
  });
}
