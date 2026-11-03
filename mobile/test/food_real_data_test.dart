import 'package:dealgo/features/food/data/food_search_history.dart';
import 'package:dealgo/features/food/domain/entities/food_models.dart';
import 'package:dealgo/features/rating/data/rating_remote_datasource.dart';
import 'package:dealgo/features/rating/domain/service_rating.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'support/auth_test_harness.dart';
import 'support/fake_food_client.dart';
import 'support/fake_identity_client.dart';

const _noodles = 'store-noodles';
const _tea = 'store-tea';

FakeFoodClient _client() => FakeFoodClient(
  stores: const [
    FoodStoreSummary(
      id: _noodles,
      name: 'Bún Bò Huế',
      category: 'noodles',
      distanceKm: 1.2,
    ),
    FoodStoreSummary(id: _tea, name: 'Trà Sữa Mây', category: 'tea'),
  ],
  details: const {
    _noodles: FoodStoreDetail(
      id: _noodles,
      name: 'Bún Bò Huế',
      category: 'noodles',
      addressLabel: '12 Lê Lợi, Hải Châu',
      items: [
        FoodMenuItem(
          id: 'i1',
          name: 'Bún bò đặc biệt',
          priceVnd: 60000,
          available: true,
        ),
      ],
    ),
    _tea: FoodStoreDetail(id: _tea, name: 'Trà Sữa Mây', items: []),
  },
);

FakeRatingRemoteDataSource _ratings() => FakeRatingRemoteDataSource(
  stores: {
    _noodles: const StoreRating(storeId: _noodles, count: 4, average: 4.5),
    _tea: const StoreRating(storeId: _tea, count: 1),
  },
  reviews: {
    _noodles: [
      StoreReview(
        stars: 5,
        tags: const [],
        comment: 'Nước dùng rất ngon',
        createdAt: DateTime(2026, 10, 18),
      ),
    ],
  },
);

Future<void> _go(WidgetTester tester, String path) async {
  GoRouter.of(tester.element(find.byType(Scaffold).first)).push(path);
  await tester.pumpAndSettle();
}

void _tall(WidgetTester tester) {
  tester.view.physicalSize = const Size(1170, 2532);
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);
}

void main() {
  testWidgets('store page shows the real rating, reviews and address', (
    tester,
  ) async {
    _tall(tester);
    await pumpSignedIn(
      tester,
      profile: customerProfile,
      foodClient: _client(),
      ratings: _ratings(),
    );
    await _go(tester, '/customer/food/stores/$_noodles');

    expect(find.text('Chi tiết quán'), findsOneWidget);
    expect(find.textContaining('4,5', findRichText: true), findsWidgets);
    expect(find.textContaining('20–30'), findsNothing);
    expect(find.textContaining('minh họa'), findsNothing);
    expect(find.textContaining('Freeship'), findsNothing);
    expect(find.text('Thực đơn · 1 món'), findsOneWidget);

    await tester.tap(find.byKey(const Key('food-store-tab-reviews')));
    await tester.pumpAndSettle();
    expect(find.text('Nước dùng rất ngon'), findsOneWidget);
    expect(find.text('18/10/2026'), findsOneWidget);

    await tester.tap(find.byKey(const Key('food-store-tab-info')));
    await tester.pumpAndSettle();
    expect(
      find.descendant(
        of: find.byKey(const Key('food-store-address')),
        matching: find.text('12 Lê Lợi, Hải Châu'),
        matchRoot: true,
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: find.byKey(const ValueKey('info')),
        matching: find.text('Bún, mì'),
      ),
      findsOneWidget,
    );
  });

  testWidgets('store with too few ratings hides the score and the reviews', (
    tester,
  ) async {
    _tall(tester);
    await pumpSignedIn(
      tester,
      profile: customerProfile,
      foodClient: _client(),
      ratings: _ratings(),
    );
    await _go(tester, '/customer/food/stores/$_tea');
    expect(find.textContaining('1 đánh giá', findRichText: true), findsWidgets);
    expect(find.text('Cửa hàng chưa có món.'), findsOneWidget);

    await tester.tap(find.byKey(const Key('food-store-tab-reviews')));
    await tester.pumpAndSettle();
    expect(
      find.text('1 đánh giá — điểm sẽ hiện khi quán có thêm đánh giá'),
      findsOneWidget,
    );

    await tester.tap(find.byKey(const Key('food-store-tab-info')));
    await tester.pumpAndSettle();
    expect(find.text('Quán chưa cập nhật địa chỉ'), findsOneWidget);
  });

  testWidgets('discovery sends the GPS fix and shows real ratings', (
    tester,
  ) async {
    _tall(tester);
    final food = _client();
    await pumpSignedIn(
      tester,
      profile: customerProfile,
      foodClient: food,
      ratings: _ratings(),
    );
    await tester.tap(find.text('Đồ ăn').first);
    await tester.pumpAndSettle();

    expect(food.storeListGeo, contains(true));
    await tester.dragUntilVisible(
      find.text('Đánh giá cao'),
      find.byType(CustomScrollView).first,
      const Offset(0, -300),
    );
    expect(find.text('Đánh giá cao'), findsOneWidget);
    expect(find.textContaining('4,5 (4)', findRichText: true), findsWidgets);
    expect(find.textContaining('1,2 km', findRichText: true), findsWidgets);
  });

  testWidgets('discovery filters reload from the server with the range', (
    tester,
  ) async {
    _tall(tester);
    final food = _client();
    await pumpSignedIn(
      tester,
      profile: customerProfile,
      foodClient: food,
      ratings: _ratings(),
    );
    await tester.tap(find.text('Đồ ăn').first);
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('food-discovery-filter')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('food-filter-km-3')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('food-filter-apply')));
    await tester.pumpAndSettle();

    expect(food.storeMaxKms.last, 3);
    expect(find.text('Trong 3 km'), findsOneWidget);
  });

  testWidgets('category page filters by the real store category', (
    tester,
  ) async {
    _tall(tester);
    await pumpSignedIn(
      tester,
      profile: customerProfile,
      foodClient: _client(),
      ratings: _ratings(),
    );
    await _go(tester, '/customer/food/category?category=tea');
    expect(find.text('Trà Sữa Mây'), findsWidgets);
    expect(find.text('Bún Bò Huế'), findsNothing);
    // Title comes from the Admin-managed list (FoodCategoriesStore).
    expect(find.text('Trà sữa'), findsWidgets);

    await _go(tester, '/customer/food/category?category=cafe');
    expect(find.byKey(const Key('food-category-empty')), findsOneWidget);
  });

  testWidgets('search shows every match and sorts on the server', (
    tester,
  ) async {
    _tall(tester);
    final food = FakeFoodClient(
      stores: [
        for (var i = 1; i <= 5; i++)
          FoodStoreSummary(id: 's$i', name: 'Quán $i', category: 'rice'),
      ],
    );
    await pumpSignedIn(
      tester,
      profile: customerProfile,
      foodClient: food,
      ratings: _ratings(),
    );
    await _go(tester, '/customer/food/search?q=qu%C3%A1n');
    expect(find.byKey(const Key('food-search-heading')), findsOneWidget);
    expect(find.text('5 kết quả'), findsOneWidget);
    expect(find.text('Quán 5'), findsOneWidget);

    await tester.tap(find.byKey(const Key('food-search-sort-rating')));
    await tester.pumpAndSettle();
    expect(food.storeSorts.last, 'rating');
  });

  test('search history keeps the 5 latest unique queries', () async {
    SharedPreferences.setMockInitialValues({});
    for (final q in ['phở', 'bún', 'Phở', 'cơm', 'trà', 'bánh', 'gà']) {
      await FoodSearchHistory.add(q);
    }
    expect(await FoodSearchHistory.load(), ['gà', 'bánh', 'trà', 'cơm', 'Phở']);
    await FoodSearchHistory.add('x');
    expect((await FoodSearchHistory.load()).first, 'gà');
  });
}
