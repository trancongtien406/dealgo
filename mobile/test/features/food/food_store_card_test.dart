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

void _noop() {}

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

  testWidgets('compact card fits the fixed discovery rail height', (
    tester,
  ) async {
    // Mirrors the "Đánh giá cao" rail height in food_discovery_page.dart.
    const railHeight = 128.0;
    for (final scale in [1.0, 1.3, 2.0]) {
      await tester.pumpWidget(
        MaterialApp(
          locale: const Locale('vi'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(textScaler: TextScaler.linear(scale)),
            child: child!,
          ),
          home: Scaffold(
            body: ListView(
              children: [
                SizedBox(
                  height: railHeight * (scale < 1 ? 1 : scale),
                  child: ListView(
                    scrollDirection: Axis.horizontal,
                    children: const [
                      SizedBox(
                        width: 288,
                        child: FoodStoreCard(
                          store: FoodStoreSummary(
                            id: 's3',
                            name: 'Quán Ăn Vặt Sinh Viên Số 1 Sài Gòn',
                            category: 'dessert',
                            distanceKm: 12.4,
                            etaMinutes: 45,
                            deliveryFeeFromVnd: 25000,
                            ratingAverage: 4.95,
                            ratingCount: 128000,
                            closesAtToday: '23:55',
                          ),
                          variant: FoodStoreCardVariant.compact,
                          onTap: _noop,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      );
      expect(tester.takeException(), isNull, reason: 'text scale $scale');
    }
  });

  testWidgets('tapping the card calls onTap', (tester) async {
    var taps = 0;
    await _pump(tester, FoodStoreCard(store: _store, onTap: () => taps++));

    await tester.tap(find.text('Bún Bò Huế'));
    expect(taps, 1);
  });
}
