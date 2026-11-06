import 'package:dealgo/core/design_system/tokens/dealgo_tokens.dart';
import 'package:dealgo/features/food/domain/entities/food_models.dart';
import 'package:dealgo/features/food/presentation/widgets/food_filter_sheet.dart';
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

  testWidgets(
    'category filter bar uses soft-corner FoodFilterPill buttons and supports quick filters + sheet',
    (tester) async {
      _tall(tester);
      final food = FakeFoodClient(
        stores: const [
          FoodStoreSummary(
            id: 's1',
            name: 'Bún Bò Mở Cửa',
            category: 'noodles',
          ),
          FoodStoreSummary(
            id: 's2',
            name: 'Bún Bò Đóng Cửa',
            category: 'noodles',
            closedReason: StoreClosedReason.closed,
          ),
        ],
      );

      await pumpSignedIn(
        tester,
        profile: customerProfile,
        foodClient: food,
        ratings: FakeRatingRemoteDataSource(),
        locationOverride: FakeLocationService(),
      );
      await _go(tester, '/customer/food/category?category=noodles');

      // Soft-square 8pt radius FoodFilterPill instead of StadiumBorder badge.
      final nearPill = tester.widget<FoodFilterPill>(
        find.byKey(const Key('food-sort-near')),
      );
      expect(nearPill.selected, isTrue);

      final pillMaterial = tester.widget<Material>(
        find
            .descendant(
              of: find.byKey(const Key('food-sort-near')),
              matching: find.byType(Material),
            )
            .first,
      );
      expect(pillMaterial.shape, isA<RoundedRectangleBorder>());
      final shape = pillMaterial.shape! as RoundedRectangleBorder;
      expect(
        shape.borderRadius,
        BorderRadius.circular(DealGoRadius.small),
      );

      // Quick filter "Đang mở cửa" hides closed stores immediately.
      expect(find.text('Bún Bò Mở Cửa'), findsOneWidget);
      expect(find.text('Bún Bò Đóng Cửa'), findsOneWidget);

      await tester.tap(find.byKey(const Key('food-category-filter-open')));
      await tester.pumpAndSettle();

      expect(find.text('Bún Bò Mở Cửa'), findsOneWidget);
      expect(find.text('Bún Bò Đóng Cửa'), findsNothing);

      // Filter button opens the full filter sheet and preserves category + maxKm.
      await tester.tap(find.byKey(const Key('food-category-filter')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('food-filter-km-slider')), findsOneWidget);
      await tester.tap(find.byKey(const Key('food-filter-km-3')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('food-filter-km-inc')));
      await tester.pumpAndSettle();
      expect(find.text('Trong 4 km'), findsOneWidget);
      await tester.tap(find.byKey(const Key('food-filter-km-dec')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('food-filter-apply')));
      await tester.pumpAndSettle();

      expect(food.storeCategories.last, 'noodles');
      expect(food.storeMaxKms.last, 3);

      // Re-open the filter sheet and pull down on its scrollable body (TikTok-style)
      // to dismiss the sheet directly without tapping close.
      await tester.tap(find.byKey(const Key('food-category-filter')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('food-filter-sheet')), findsOneWidget);

      await tester.drag(
        find.byKey(const Key('food-filter-sheet')),
        const Offset(0, 260),
      );
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('food-filter-sheet')), findsNothing);
    },
  );

  test('FoodFilters.matches filters by rating, ETA, min order, and distance', () {
    const fastTopStore = FoodStoreSummary(
      id: 's1',
      name: 'Phở Ngon',
      distanceKm: 1.8,
      ratingAverage: 4.7,
      ratingCount: 20,
      etaMinutes: 18,
      minOrderVnd: 0,
    );
    const slowMinOrderStore = FoodStoreSummary(
      id: 's2',
      name: 'Phở Xa',
      distanceKm: 4.5,
      ratingAverage: 3.8,
      ratingCount: 12,
      etaMinutes: 40,
      minOrderVnd: 50000,
    );

    const strict = FoodFilters(
      maxKm: 2,
      minRating: 4.5,
      maxEtaMinutes: 20,
      noMinOrder: true,
    );

    expect(strict.matches(fastTopStore), isTrue);
    expect(strict.matches(slowMinOrderStore), isFalse);
    expect(strict.activeCount, 4);
  });
}
