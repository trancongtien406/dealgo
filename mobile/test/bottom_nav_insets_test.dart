import 'package:dealgo/core/design_system/components/dealgo_nav_insets.dart';
import 'package:dealgo/core/design_system/components/dealgo_tab_bar.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Future<double> _barHeight(
  WidgetTester tester,
  TargetPlatform platform,
  double viewPaddingBottom, {
  double keyboard = 0,
}) async {
  debugDefaultTargetPlatformOverride = platform;
  addTearDown(() => debugDefaultTargetPlatformOverride = null);
  await tester.pumpWidget(
    MaterialApp(
      home: MediaQuery(
        data: MediaQueryData(
          size: const Size(430, 932),
          viewPadding: EdgeInsets.only(bottom: viewPaddingBottom),
          // With the keyboard open, padding.bottom drops to 0 but viewPadding stays.
          padding: EdgeInsets.only(
            bottom: keyboard > 0 ? 0 : viewPaddingBottom,
          ),
          viewInsets: EdgeInsets.only(bottom: keyboard),
        ),
        child: Scaffold(
          bottomNavigationBar: DealGoTabBar(
            selectedIndex: 0,
            onDestinationSelected: (_) {},
            destinations: const [
              DealGoTabDestination(
                label: 'A',
                icon: Icons.home_outlined,
                selectedIcon: Icons.home,
              ),
              DealGoTabDestination(
                label: 'B',
                icon: Icons.person_outline,
                selectedIcon: Icons.person,
              ),
            ],
          ),
        ),
      ),
    ),
  );
  final h = tester.getSize(find.byType(DealGoTabBar)).height;
  debugDefaultTargetPlatformOverride = null;
  return h;
}

void main() {
  test('metrics: pill clears the home indicator / system navigation', () {
    // overhang 20 + pill 58 + bottom gap.
    expect(dealGoNavBarMetrics(TargetPlatform.iOS, 34).totalHeight, 102);
    expect(dealGoNavBarMetrics(TargetPlatform.iOS, 34).bottomGap, 24);
    expect(
      dealGoNavBarMetrics(TargetPlatform.iOS, 0).totalHeight,
      88,
    ); // iPhone SE / Touch ID
    expect(
      dealGoNavBarMetrics(TargetPlatform.android, 48).totalHeight,
      132,
    ); // 3-button
    expect(
      dealGoNavBarMetrics(TargetPlatform.android, 24).totalHeight,
      108,
    ); // gesture
    expect(
      dealGoNavBarMetrics(TargetPlatform.android, 0).totalHeight,
      88,
    ); // no nav bar
    expect(dealGoNavBarMetrics(TargetPlatform.android, -1).bottomInset, 0);
    expect(dealGoNavBarMetrics(TargetPlatform.iOS, 34).contentClearance, 82);
  });

  testWidgets('iOS home indicator 34 -> bar 102', (tester) async {
    expect(await _barHeight(tester, TargetPlatform.iOS, 34), 102);
  });
  testWidgets('Android 3-button 48 -> bar 132', (tester) async {
    expect(await _barHeight(tester, TargetPlatform.android, 48), 132);
  });
  testWidgets('Android gesture 24 -> bar 108', (tester) async {
    expect(await _barHeight(tester, TargetPlatform.android, 24), 108);
  });
  testWidgets('Android without nav bar -> bar 88', (tester) async {
    expect(await _barHeight(tester, TargetPlatform.android, 0), 88);
  });
  testWidgets('keyboard open keeps the bar height (uses viewPadding)', (
    tester,
  ) async {
    expect(
      await _barHeight(tester, TargetPlatform.iOS, 34, keyboard: 300),
      102,
    );
  });
}
