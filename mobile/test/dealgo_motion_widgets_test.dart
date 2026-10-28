import 'package:dealgo/core/motion/dealgo_motion_widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _host(Widget child, {bool reduce = false}) => MaterialApp(
  home: MediaQuery(
    data: MediaQueryData(disableAnimations: reduce),
    child: Scaffold(body: Center(child: child)),
  ),
);

double _opacity(WidgetTester tester) => tester
    .widget<FadeTransition>(
      find.descendant(
        of: find.byType(DealGoStaggerIn),
        matching: find.byType(FadeTransition),
      ),
    )
    .opacity
    .value;

void main() {
  testWidgets('stagger fades a row in within 300ms after its slot', (
    tester,
  ) async {
    await tester.pumpWidget(
      _host(const DealGoStaggerIn(index: 2, child: Text('row'))),
    );
    expect(_opacity(tester), 0);
    await tester.pump(const Duration(milliseconds: 80));
    await tester.pump(const Duration(milliseconds: 300));
    expect(_opacity(tester), 1);
  });

  testWidgets('stagger delay is capped for long lists', (tester) async {
    await tester.pumpWidget(
      _host(const DealGoStaggerIn(index: 50, child: Text('row'))),
    );
    await tester.pump(DealGoStaggerIn.step * DealGoStaggerIn.maxStaggered);
    await tester.pump(const Duration(milliseconds: 300));
    expect(_opacity(tester), 1);
  });

  testWidgets('reduced motion shows rows immediately and keeps pulse still', (
    tester,
  ) async {
    await tester.pumpWidget(
      _host(
        const Column(
          children: [
            DealGoStaggerIn(index: 3, child: Text('row')),
            DealGoPulse(color: Colors.purple, child: Text('car')),
          ],
        ),
        reduce: true,
      ),
    );
    expect(_opacity(tester), 1);
    // No ring layers and no ticking controller: settles at once.
    expect(
      find.descendant(
        of: find.byType(DealGoPulse),
        matching: find.byType(Transform),
      ),
      findsNothing,
    );
    expect(tester.hasRunningAnimations, isFalse);
  });

  testWidgets('pulse loop is skipped in widget tests so frames settle', (
    tester,
  ) async {
    await tester.pumpWidget(
      _host(const DealGoPulse(color: Colors.purple, child: Text('car'))),
    );
    await tester.pumpAndSettle();
    expect(find.text('car'), findsOneWidget);
    expect(tester.hasRunningAnimations, isFalse);
  });

  testWidgets('status switcher cross-fades to the new status', (tester) async {
    Widget status(String s) =>
        _host(DealGoStatusSwitcher(child: Text(s, key: ValueKey(s))));
    await tester.pumpWidget(status('Đang chuẩn bị'));
    await tester.pumpWidget(status('Đang giao'));
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.text('Đang chuẩn bị'), findsOneWidget);
    expect(find.text('Đang giao'), findsOneWidget);
    await tester.pumpAndSettle();
    expect(find.text('Đang chuẩn bị'), findsNothing);
    expect(find.text('Đang giao'), findsOneWidget);
  });

  testWidgets('hero is disabled under reduced motion', (tester) async {
    await tester.pumpWidget(
      _host(const DealGoHero(tag: 't', child: Text('photo')), reduce: true),
    );
    expect(tester.widget<HeroMode>(find.byType(HeroMode)).enabled, isFalse);
  });
}
