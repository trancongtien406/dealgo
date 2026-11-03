import 'package:dealgo/features/food/domain/entities/food_models.dart';
import 'package:dealgo/features/rating/data/rating_remote_datasource.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import '../../support/auth_test_harness.dart';
import '../../support/fake_food_client.dart';
import '../../support/fake_identity_client.dart';
import '../../support/fake_location.dart';

Future<void> _go(WidgetTester tester, String path) async {
  GoRouter.of(tester.element(find.byType(Scaffold).first)).push(path);
  await tester.pumpAndSettle();
}

FakeFoodClient _client() => FakeFoodClient(
  stores: const [
    FoodStoreSummary(id: 's1', name: 'Bún bò', category: 'noodles'),
    FoodStoreSummary(id: 's2', name: 'Trà Sữa Mây', category: 'tea'),
  ],
);

FakeFoodClient _manyNoodles(int count) => FakeFoodClient(
  stores: [
    for (var i = 0; i < count; i++)
      FoodStoreSummary(id: 'n$i', name: 'Quán bún $i', category: 'noodles'),
  ],
);

/// Search pages over the client's stores, which the default fake does not.
class _PagedSearchFoodClient extends FakeFoodClient {
  _PagedSearchFoodClient({required super.stores});

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
    searchSorts.add(sortBy);
    searchPages.add(page);
    searchLimits.add(limit);
    final start = (page - 1) * limit;
    final items = start >= stores.length
        ? const <FoodStoreSummary>[]
        : stores.sublist(start, (start + limit).clamp(0, stores.length));
    return FoodSearchResult(
      dishes: const [],
      dishTotal: 0,
      stores: items,
      storeTotal: stores.length,
    );
  }
}

Future<void> _dragUntilPage(
  WidgetTester tester,
  Finder list,
  List<int> pages,
  int page,
) async {
  for (var i = 0; i < 10 && !pages.contains(page); i++) {
    await tester.drag(list, const Offset(0, -1200));
    await tester.pumpAndSettle();
  }
}

void _tall(WidgetTester tester) {
  tester.view.physicalSize = const Size(1170, 2532);
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);
}

void main() {
  testWidgets('the category page asks for the code and the first page', (
    tester,
  ) async {
    _tall(tester);
    final food = _client();

    await pumpSignedIn(
      tester,
      profile: customerProfile,
      foodClient: food,
      ratings: FakeRatingRemoteDataSource(),
      locationOverride: FakeLocationService(),
    );
    await _go(tester, '/customer/food/category?category=noodles');

    expect(food.storeCategories, contains('noodles'));
    expect(food.storePages, contains(1));
    expect(food.storeLimits, contains(20));
    expect(find.text('Trà Sữa Mây'), findsNothing);
  });

  testWidgets('the category sort keeps the category filter', (tester) async {
    _tall(tester);
    final food = _client();

    await pumpSignedIn(
      tester,
      profile: customerProfile,
      foodClient: food,
      ratings: FakeRatingRemoteDataSource(),
      locationOverride: FakeLocationService(),
    );
    await _go(tester, '/customer/food/category?category=noodles');

    await tester.tap(find.byKey(const Key('food-sort-rating')));
    await tester.pumpAndSettle();

    expect(food.storeSorts.last, 'rating');
    expect(food.storeCategories.last, 'noodles');
  });

  testWidgets('search keeps the query and sends the chosen sort', (
    tester,
  ) async {
    _tall(tester);
    final food = _client();

    await pumpSignedIn(
      tester,
      profile: customerProfile,
      foodClient: food,
      ratings: FakeRatingRemoteDataSource(),
      locationOverride: FakeLocationService(),
    );
    await _go(tester, '/customer/food/search');

    await tester.enterText(find.byKey(const Key('food-search-field')), 'bún');
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pumpAndSettle();

    expect(food.searchQueries.last, 'bún');
    expect(food.searchSorts.last, 'distance');

    await tester.tap(find.byKey(const Key('food-search-sort-rating')));
    await tester.pumpAndSettle();

    expect(food.searchSorts.last, 'rating');
    expect(food.searchQueries.last, 'bún');
  });

  testWidgets('the category feed loads page 2 with the same filter', (
    tester,
  ) async {
    _tall(tester);
    final food = _manyNoodles(25);

    await pumpSignedIn(
      tester,
      profile: customerProfile,
      foodClient: food,
      ratings: FakeRatingRemoteDataSource(),
      locationOverride: FakeLocationService(),
    );
    await _go(tester, '/customer/food/category?category=noodles');

    expect(food.storePages.where((page) => page > 1), isEmpty);

    await _dragUntilPage(
      tester,
      find.byType(ListView).first,
      food.storePages,
      2,
    );

    expect(food.storePages, contains(2));
    expect(food.storeCategories.last, 'noodles');
    expect(food.storeSorts.last, 'distance');
    expect(food.storeLimits.last, 20);
  });

  testWidgets('the search feed loads page 2 with the query intact', (
    tester,
  ) async {
    _tall(tester);
    final food = _PagedSearchFoodClient(stores: _manyNoodles(25).stores);

    await pumpSignedIn(
      tester,
      profile: customerProfile,
      foodClient: food,
      ratings: FakeRatingRemoteDataSource(),
      locationOverride: FakeLocationService(),
    );
    await _go(tester, '/customer/food/search');

    await tester.enterText(find.byKey(const Key('food-search-field')), 'bún');
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pumpAndSettle();
    expect(food.searchPages.where((page) => page > 1), isEmpty);

    await _dragUntilPage(
      tester,
      find.byType(ListView).last,
      food.searchPages,
      2,
    );

    expect(food.searchPages, contains(2));
    expect(food.searchQueries.last, 'bún');
    expect(food.searchSorts.last, 'distance');
    expect(food.searchLimits.last, 20);
  });

  testWidgets('a query without matches shows the empty state, not a footer', (
    tester,
  ) async {
    _tall(tester);
    final food = _client();

    await pumpSignedIn(
      tester,
      profile: customerProfile,
      foodClient: food,
      ratings: FakeRatingRemoteDataSource(),
      locationOverride: FakeLocationService(),
    );
    await _go(tester, '/customer/food/search');

    await tester.enterText(find.byKey(const Key('food-search-field')), 'zzz');
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('food-feed-end')), findsNothing);
    expect(find.byKey(const Key('food-feed-retry')), findsNothing);
  });
}
