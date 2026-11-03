import 'package:dealgo/features/food/domain/entities/food_models.dart';
import 'package:dealgo/features/food/presentation/widgets/food_store_card.dart';
import 'package:dealgo/l10n/app_localizations.dart';
import 'package:dealgo/l10n/app_localizations_vi.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

const _store = FoodStoreSummary(
  id: 's1',
  name: 'Bún Bò Huế',
  category: 'noodles',
  distanceKm: 1.2,
  etaMinutes: 25,
  deliveryFeeFromVnd: 15000,
  minOrderVnd: 30000,
  featuredItems: [
    FoodFeaturedItem(id: 'i1', name: 'Bún đặc biệt', priceVnd: 60000),
    FoodFeaturedItem(id: 'i2', name: 'Bún tái', priceVnd: 55000),
  ],
);

Future<void> _pump(WidgetTester tester, Widget child) {
  return tester.pumpWidget(
    MaterialApp(
      locale: const Locale('vi'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(body: child),
    ),
  );
}

void main() {
  testWidgets('feed card shows the two signature dishes and the meta line', (
    tester,
  ) async {
    await _pump(tester, FoodStoreCard(store: _store, onTap: () {}));

    expect(find.text('Bún Bò Huế'), findsOneWidget);
    expect(find.text('Bún đặc biệt'), findsOneWidget);
    expect(find.text('Bún tái'), findsOneWidget);
    expect(find.byKey(const Key('store-meta-s1')), findsOneWidget);
  });

  testWidgets('compact card drops the dish rows', (tester) async {
    await _pump(
      tester,
      FoodStoreCard(
        store: _store,
        variant: FoodStoreCardVariant.compact,
        onTap: () {},
      ),
    );

    expect(find.text('Bún Bò Huế'), findsOneWidget);
    expect(find.text('Bún đặc biệt'), findsNothing);
    expect(find.byKey(const Key('store-eta-fee-s1')), findsOneWidget);
  });

  testWidgets('a closed store keeps its label and never fakes a rating', (
    tester,
  ) async {
    await _pump(
      tester,
      FoodStoreCard(
        store: const FoodStoreSummary(
          id: 's2',
          name: 'Quán đóng',
          closedReason: StoreClosedReason.closed,
        ),
        onTap: () {},
      ),
    );

    expect(
      find.text(AppLocalizationsVi().foodStoreClosedLabel),
      findsOneWidget,
    );
    expect(find.byKey(const Key('store-eta-fee-s2')), findsNothing);
  });

  testWidgets('tapping the card calls onTap', (tester) async {
    var taps = 0;
    await _pump(tester, FoodStoreCard(store: _store, onTap: () => taps++));

    await tester.tap(find.text('Bún Bò Huế'));
    expect(taps, 1);
  });
}
