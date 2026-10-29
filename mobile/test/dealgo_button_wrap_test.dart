import 'package:dealgo/core/design_system/components/dealgo_primary_button.dart';
import 'package:dealgo/core/design_system/components/dealgo_secondary_button.dart';
import 'package:dealgo/core/design_system/icons/dealgo_icons.dart';
import 'package:dealgo/core/design_system/theme/dealgo_theme.dart';
import 'package:flutter/material.dart';
import "package:flutter/rendering.dart";
import 'package:flutter_test/flutter_test.dart';

const _short = 'Đặt xe';
const _long =
    'Xác nhận đặt xe và thanh toán bằng ví DealGo cho chuyến đi này ngay bây giờ';

Future<void> _pump(
  WidgetTester tester,
  Widget child, {
  double scale = 1,
  double width = 320,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      theme: DealGoTheme.light,
      home: MediaQuery(
        data: MediaQueryData(
          size: Size(width, 800),
          textScaler: TextScaler.linear(scale),
        ),
        child: Scaffold(
          body: Center(
            child: SizedBox(width: width - 32, child: child),
          ),
        ),
      ),
    ),
  );
  await tester.pump();
}

double _lineHeight(WidgetTester tester, Finder text) {
  final paragraph = tester.renderObject<RenderParagraph>(text);
  return paragraph.size.height;
}

void main() {
  for (final scale in [1.0, 1.3, 2.0]) {
    testWidgets('primary: 1 line vs wrapped label at text scale $scale', (
      tester,
    ) async {
      await _pump(
        tester,
        DealGoPrimaryButton(label: _short, onPressed: () {}),
        scale: scale,
      );
      final oneLine = tester.getSize(find.byType(FilledButton)).height;
      expect(oneLine, greaterThanOrEqualTo(52));
      expect(tester.takeException(), isNull);

      await _pump(
        tester,
        DealGoPrimaryButton(
          label: _long,
          trailingIcon: DealGoIcons.arrowRight,
          onPressed: () {},
        ),
        scale: scale,
      );
      expect(tester.takeException(), isNull, reason: 'no overflow');
      final button = tester.getRect(find.byType(FilledButton));
      final text = tester.getRect(find.text(_long));
      // Wrapped, not shrunk to fit: the button grew to hold the lines.
      expect(_lineHeight(tester, find.text(_long)), greaterThan(16 * scale));
      expect(button.height, greaterThan(oneLine));
      // Balanced: same space above and below the text, all inside the button.
      expect(
        (text.top - button.top) - (button.bottom - text.bottom),
        moreOrLessEquals(0, epsilon: 1.5),
      );
      expect(text.top - button.top, greaterThanOrEqualTo(11));
      // Label is centered horizontally too.
      final paragraph = tester.renderObject<RenderParagraph>(find.text(_long));
      expect(paragraph.textAlign, TextAlign.center);
      // Icon sits on the label's vertical center.
      final icon = tester.getCenter(find.byIcon(DealGoIcons.arrowRight));
      expect(icon.dy, moreOrLessEquals(text.center.dy, epsilon: 1.5));
    });
  }

  testWidgets('secondary grows the same way and keeps its min height', (
    tester,
  ) async {
    await _pump(tester, DealGoSecondaryButton(label: _short, onPressed: () {}));
    final one = tester.getSize(find.byType(OutlinedButton)).height;
    expect(one, greaterThanOrEqualTo(52));
    await _pump(
      tester,
      DealGoSecondaryButton(label: _long, onPressed: () {}),
      scale: 1.3,
    );
    expect(tester.takeException(), isNull);
    final button = tester.getRect(find.byType(OutlinedButton));
    final text = tester.getRect(find.text(_long));
    expect(button.height, greaterThan(one));
    expect(
      (text.top - button.top) - (button.bottom - text.bottom),
      moreOrLessEquals(0, epsilon: 1.5),
    );
  });

  testWidgets('side-by-side CTA pair stays the same height when one wraps', (
    tester,
  ) async {
    await _pump(
      tester,
      IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: DealGoSecondaryButton(label: 'Huỷ', onPressed: () {}),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: DealGoPrimaryButton(label: _long, onPressed: () {}),
            ),
          ],
        ),
      ),
      scale: 1.3,
    );
    expect(tester.takeException(), isNull);
    expect(
      tester.getSize(find.byType(OutlinedButton)).height,
      tester.getSize(find.byType(FilledButton)).height,
    );
  });

  testWidgets('theme FilledButton has no fixed height', (tester) async {
    await _pump(
      tester,
      FilledButton(
        onPressed: () {},
        child: const Text(_long, textAlign: TextAlign.center),
      ),
      scale: 2,
    );
    expect(tester.takeException(), isNull);
    final button = tester.getRect(find.byType(FilledButton));
    final text = tester.getRect(find.text(_long));
    expect(button.height, greaterThan(text.height));
    expect(text.top - button.top, greaterThanOrEqualTo(11));
  });
}
