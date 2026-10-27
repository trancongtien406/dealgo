import 'package:dealgo/features/merchant/presentation/pages/merchant_products_page.dart';
import 'package:dealgo/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

// Save on "Thêm món" red-screened because the controllers were
// disposed while the dialog route was still animating out.
void main() {
  testWidgets('add-item dialog returns values and closes without errors', (
    tester,
  ) async {
    ({String name, String price})? result;
    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('vi'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Builder(
          builder: (context) => TextButton(
            onPressed: () async {
              result = await showDialog<({String name, String price})>(
                context: context,
                builder: (_) => const MerchantAddItemDialog(),
              );
            },
            child: const Text('open'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const Key('merchant-catalog-name')),
      'Cơm tấm',
    );
    await tester.enterText(
      find.byKey(const Key('merchant-catalog-price')),
      '45000',
    );
    await tester.tap(find.byKey(const Key('merchant-catalog-create')));
    // Pump through the exit animation frame by frame: the old code threw here.
    for (var i = 0; i < 20; i++) {
      await tester.pump(const Duration(milliseconds: 20));
    }
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(result, (name: 'Cơm tấm', price: '45000'));
    expect(find.byType(MerchantAddItemDialog), findsNothing);
  });
}
