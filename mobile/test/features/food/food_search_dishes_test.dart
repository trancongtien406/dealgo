import 'package:dealgo/core/mock/fake_food_client.dart';
import 'package:dealgo/features/food/data/repositories/food_repository_impl.dart';
import 'package:dealgo/features/food/domain/entities/food_models.dart';
import 'package:dealgo/features/food/presentation/cubit/food_search_cubit.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/auth_test_harness.dart';
import '../../support/fake_identity_client.dart';

class _PagedSearchClient extends FakeFoodClient {
  @override
  Future<FoodSearchResult> searchFood(
    String accessToken, {
    required String q,
    double? lat,
    double? lng,
    String? sortBy,
    int page = 1,
    int limit = 20,
  }) async {
    searchQueries.add(q.trim());
    searchPages.add(page);
    if (page > 1) {
      return FoodSearchResult(
        dishes: [
          dishHit(name: 'Món 20', storeId: 's20', itemId: 'i20'),
          dishHit(name: 'Món 0', storeId: 's0', itemId: 'i0'),
        ],
        dishTotal: 21,
        stores: [storeSummary(id: 'store-1', name: 'Quán 1')],
        storeTotal: 1,
      );
    }
    return FoodSearchResult(
      dishes: [
        for (var i = 0; i < 20; i++)
          dishHit(name: 'Món $i', storeId: 's$i', itemId: 'i$i'),
      ],
      dishTotal: 21,
      stores: [storeSummary(id: 'store-1', name: 'Quán 1')],
      storeTotal: 1,
    );
  }
}

void _tall(WidgetTester tester) {
  tester.view.physicalSize = const Size(1170, 2532);
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);
}

Future<void> _openSearch(WidgetTester tester) async {
  await tester.tap(find.text('Đồ ăn').first);
  await tester.pumpAndSettle();
  await tester.tap(find.byKey(const Key('food-search-entry')));
  await tester.pumpAndSettle();
}

Future<void> _search(WidgetTester tester, String q) async {
  await tester.enterText(find.byKey(const Key('food-search-field')), q);
  await tester.pump(const Duration(milliseconds: 400));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('dish hits render above store results and open the item page', (
    tester,
  ) async {
    _tall(tester);
    final food = FakeFoodClient()
      ..searchFoodHandler = (q) => FoodSearchResult(
        dishes: [
          dishHit(
            name: 'Bún bò',
            storeId: 'store-1',
            itemId: 'item-bun',
            storeName: 'Bún Bò Huế',
            distanceKm: 1.2,
            etaMinutes: 25,
            deliveryFeeFromVnd: 15000,
          ),
        ],
        dishTotal: 1,
        stores: [storeSummary(id: 'store-1', name: 'Bún Bò Huế')],
        storeTotal: 1,
      );

    await pumpSignedIn(tester, profile: customerProfile, foodClient: food);
    await _openSearch(tester);
    await _search(tester, 'bún');

    expect(find.byKey(const Key('food-dish-hits')), findsOneWidget);
    expect(find.text('Món ăn'), findsOneWidget);
    expect(find.text('Quán'), findsOneWidget);

    final dish = find.byKey(const Key('food-dish-hit-item-bun'));
    expect(dish, findsOneWidget);
    expect(
      tester.getTopLeft(dish).dy,
      lessThan(
        tester.getTopLeft(find.byKey(const Key('food-store-card-store-1'))).dy,
      ),
    );

    await tester.ensureVisible(dish);
    await tester.tap(dish);
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('food-item-qty')), findsOneWidget);
    expect(find.text('Bún bò'), findsWidgets);
  });

  testWidgets('no dish hits means no dish heading', (tester) async {
    _tall(tester);
    final food = FakeFoodClient()
      ..searchFoodHandler = (q) => FoodSearchResult(
        dishes: const [],
        dishTotal: 0,
        stores: [storeSummary(id: 'store-1', name: 'Bún Bò Huế')],
        storeTotal: 1,
      );

    await pumpSignedIn(tester, profile: customerProfile, foodClient: food);
    await _openSearch(tester);
    await _search(tester, 'bún');

    expect(find.text('Món ăn'), findsNothing);
    expect(find.byKey(const Key('food-dish-hits')), findsNothing);
    expect(find.text('Quán'), findsOneWidget);
  });

  testWidgets('clearing the box offers keyword chips from loaded dishes', (
    tester,
  ) async {
    _tall(tester);
    final food = FakeFoodClient()
      ..searchFoodHandler = (q) => FoodSearchResult(
        dishes: [dishHit(name: 'Bún bò', storeId: 'store-1', itemId: 'i1')],
        dishTotal: 1,
        stores: [
          storeSummary(
            id: 'store-1',
            name: 'Bún Bò Huế',
            featuredItems: const [
              FoodFeaturedItem(id: 'i1', name: 'Bún bò', priceVnd: 45000),
            ],
          ),
        ],
        storeTotal: 1,
      );

    await pumpSignedIn(tester, profile: customerProfile, foodClient: food);
    await _openSearch(tester);
    await _search(tester, 'bún');

    await tester.enterText(find.byKey(const Key('food-search-field')), '');
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pumpAndSettle();

    final chip = find.byKey(const Key('food-search-keyword-Bún bò'));
    expect(chip, findsOneWidget);

    await tester.tap(chip);
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pumpAndSettle();
    expect(food.searchQueries.last, 'Bún bò');
  });

  test('loadMore appends the next page without duplicating rows', () async {
    final client = _PagedSearchClient();
    final cubit = FoodSearchCubit(FoodRepositoryImpl(client));
    addTearDown(cubit.close);

    await cubit.load('tok', q: 'bún');
    final first = cubit.state;
    expect(first, isA<FoodSearchReady>());
    expect((first as FoodSearchReady).dishes, hasLength(20));

    await cubit.loadMore();

    final ready = cubit.state as FoodSearchReady;
    expect(ready.dishes, hasLength(21));
    expect(ready.dishes.map((hit) => hit.item.id).toSet(), hasLength(21));
    expect(ready.page, 2);
    expect(client.searchPages, [1, 2]);
    expect(client.searchQueries.last, 'bún');
  });
}
