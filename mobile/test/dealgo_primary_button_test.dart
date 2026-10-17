import 'package:dealgo/core/design_system/components/dealgo_primary_button.dart';
import 'package:dealgo/core/design_system/theme/dealgo_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('disabled and loading primary button does not call onPressed', (
    tester,
  ) async {
    var presses = 0;

    Future<void> pumpButton({
      required bool enabled,
      required bool isLoading,
    }) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: DealGoTheme.light,
          home: Scaffold(
            body: DealGoPrimaryButton(
              label: 'Tiếp tục',
              enabled: enabled,
              isLoading: isLoading,
              onPressed: () => presses++,
            ),
          ),
        ),
      );
    }

    await pumpButton(enabled: true, isLoading: false);
    await tester.tap(find.byType(DealGoPrimaryButton));
    await tester.pump();
    expect(presses, 1);

    await pumpButton(enabled: false, isLoading: false);
    await tester.tap(find.byType(DealGoPrimaryButton), warnIfMissed: false);
    await tester.pump();
    expect(presses, 1);

    await pumpButton(enabled: true, isLoading: true);
    await tester.tap(find.byType(DealGoPrimaryButton), warnIfMissed: false);
    await tester.pump();
    expect(presses, 1);

    await tester.pumpWidget(const SizedBox.shrink());
  });
}
