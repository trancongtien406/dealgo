import 'package:dealgo/core/design_system/components/dealgo_bottom_bar.dart';
import 'package:dealgo/core/design_system/components/dealgo_nav_insets.dart';
import 'package:dealgo/core/design_system/components/dealgo_primary_button.dart';
import 'package:dealgo/core/design_system/theme/dealgo_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Mirrors help_center_page / food_cart_page: extendBody + bottom bar, list
/// padded with dealGoScrollPadding from a context under the Scaffold.
void main() {
  testWidgets('list end clears a 2-line bottom bar at text scale 2.0', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(375 * 3, 667 * 3);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        theme: DealGoTheme.light,
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(
            textScaler: const TextScaler.linear(2),
            padding: const EdgeInsets.only(bottom: 34),
          ),
          child: child!,
        ),
        home: Scaffold(
          extendBody: true,
          body: SafeArea(
            bottom: false,
            child: Builder(
              builder: (ctx) => ListView(
                padding: dealGoScrollPadding(ctx, const EdgeInsets.all(16)),
                children: [
                  for (var i = 0; i < 30; i++)
                    SizedBox(height: 60, key: ValueKey(i), child: Text('$i')),
                ],
              ),
            ),
          ),
          bottomNavigationBar: DealGoBottomBar(
            key: const ValueKey('bar'),
            child: DealGoPrimaryButton(
              label: 'Xác nhận đặt món và thanh toán bằng ví DealGo ngay',
              onPressed: () {},
            ),
          ),
        ),
      ),
    );
    await tester.drag(find.byType(ListView), const Offset(0, -5000));
    await tester.pumpAndSettle();
    final barTop = tester.getTopLeft(find.byKey(const ValueKey('bar'))).dy;
    final lastBottom = tester.getBottomLeft(find.byKey(const ValueKey(29))).dy;
    expect(
      tester.getSize(find.byKey(const ValueKey('bar'))).height,
      greaterThan(52 + 34 + 24),
    );
    expect(lastBottom, lessThanOrEqualTo(barTop));
  });
}
