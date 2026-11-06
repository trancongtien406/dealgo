import 'package:dealgo/core/design_system/components/dealgo_nav_insets.dart';
import 'package:dealgo/core/design_system/tokens/dealgo_tokens.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Future<({double sticky, EdgeInsets scroll})> _insets(
  WidgetTester tester, {
  required double viewPadding,
  double padding = 0,
  double keyboard = 0,
}) async {
  late double sticky;
  late EdgeInsets scroll;
  await tester.pumpWidget(
    MaterialApp(
      home: MediaQuery(
        data: MediaQueryData(
          size: const Size(390, 844),
          viewPadding: EdgeInsets.only(bottom: viewPadding),
          padding: EdgeInsets.only(bottom: padding),
          viewInsets: EdgeInsets.only(bottom: keyboard),
        ),
        child: Builder(
          builder: (context) {
            sticky = dealGoStickyFooterBottom(context);
            scroll = dealGoScrollPadding(
              context,
              const EdgeInsets.only(bottom: DealGoSpacing.s16),
            );
            return const SizedBox.shrink();
          },
        ),
      ),
    ),
  );
  return (sticky: sticky, scroll: scroll);
}

void main() {
  testWidgets('sticky footer clears the tab bar plus the 12dp gutter', (
    tester,
  ) async {
    // A role shell publishes the floating bar height as padding.bottom.
    final insets = await _insets(tester, viewPadding: 34, padding: 102);
    expect(insets.sticky, 102 + DealGoSpacing.s12);
  });

  testWidgets('sticky footer clears the system inset plus the 12dp gutter', (
    tester,
  ) async {
    final insets = await _insets(tester, viewPadding: 34, padding: 34);
    expect(insets.sticky, 34 + DealGoSpacing.s12);
  });

  testWidgets('sticky footer adds nothing inside a bottom SafeArea', (
    tester,
  ) async {
    // The enclosing SafeArea already consumed the inset, so padding.bottom
    // reads 0 and the CTA only keeps its gutter.
    final insets = await _insets(tester, viewPadding: 34);
    expect(insets.sticky, DealGoSpacing.s12);
  });

  testWidgets('open keyboard already sits under the sticky footer', (
    tester,
  ) async {
    final insets = await _insets(tester, viewPadding: 34, keyboard: 320);
    expect(insets.sticky, DealGoSpacing.s12);
  });

  testWidgets('scroll padding follows what the screen already reserves', (
    tester,
  ) async {
    final insets = await _insets(tester, viewPadding: 34, padding: 102);
    expect(insets.scroll.bottom, DealGoSpacing.s16 + 102);
  });

  testWidgets('scroll padding adds nothing inside a bottom SafeArea', (
    tester,
  ) async {
    // SafeArea has already consumed the inset, so padding.bottom is 0.
    final insets = await _insets(tester, viewPadding: 34);
    expect(insets.scroll.bottom, DealGoSpacing.s16);
  });
}
