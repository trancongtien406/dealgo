import 'dart:async';

import 'package:dealgo/core/network/api_exception.dart';
import 'package:dealgo/features/food/domain/entities/food_models.dart';
import 'package:dealgo/features/food/presentation/widgets/food_store_card.dart';
import 'package:dealgo/features/home_banner/data/home_banner_remote_datasource.dart';
import 'package:dealgo/features/home_banner/domain/home_banner.dart';
import 'package:dealgo/features/rating/data/rating_remote_datasource.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import '../../support/auth_test_harness.dart';
import '../../support/fake_food_client.dart';
import '../../support/fake_identity_client.dart';
import '../../support/fake_location.dart';

List<FoodStoreSummary> _manyStores(int count) => [
  for (var i = 0; i < count; i++)
    FoodStoreSummary(id: 'store-$i', name: 'Quán $i', category: 'noodles'),
];

class _FailingSecondPageFoodClient extends FakeFoodClient {
  _FailingSecondPageFoodClient({required super.stores});

  var failedRequests = 0;

  @override
  Future<FoodStorePageResult> listStores(
    String accessToken, {
    double? lat,
    double? lng,
    String? search,
    String? sortBy,
    int? maxKm,
    String? category,
    int page = 1,
    int limit = 20,
  }) async {
    if (page > 1) {
      failedRequests += 1;
      throw const ApiException(
        statusCode: 503,
        message: 'unavailable',
        errorCode: 'TEST_UNAVAILABLE',
      );
    }
    return super.listStores(
      accessToken,
      lat: lat,
      lng: lng,
      search: search,
      sortBy: sortBy,
      maxKm: maxKm,
      category: category,
      page: page,
      limit: limit,
    );
  }
}

class _GatedFoodClient extends FakeFoodClient {
  _GatedFoodClient({required super.stores});

  Completer<void>? gate;

  @override
  Future<FoodStorePageResult> listStores(
    String accessToken, {
    double? lat,
    double? lng,
    String? search,
    String? sortBy,
    int? maxKm,
    String? category,
    int page = 1,
    int limit = 20,
  }) async {
    final pending = gate;
    if (pending != null && page == 1) {
      await pending.future;
    }
    return super.listStores(
      accessToken,
      lat: lat,
      lng: lng,
      search: search,
      sortBy: sortBy,
      maxKm: maxKm,
      category: category,
      page: page,
      limit: limit,
    );
  }
}

Future<void> _pump(WidgetTester tester, FakeFoodClient food) async {
  tester.view.physicalSize = const Size(1170, 2532);
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);

  await pumpSignedIn(
    tester,
    profile: customerProfile,
    foodClient: food,
    ratings: FakeRatingRemoteDataSource(),
    locationOverride: FakeLocationService(),
  );
  await tester.tap(find.text('Đồ ăn').first);
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('renders the feed and loads page 2 on scroll', (tester) async {
    final food = FakeFoodClient(stores: _manyStores(25));
    await _pump(tester, food);

    expect(find.byType(FoodStoreCard), findsWidgets);
    expect(food.storePages.first, 1);

    for (var i = 0; i < 8 && !food.storePages.contains(2); i++) {
      await tester.drag(
        find.byType(CustomScrollView).first,
        const Offset(0, -1200),
      );
      await tester.pumpAndSettle();
    }

    expect(food.storePages, contains(2));
  });

  testWidgets('the end label appears once the last page landed', (
    tester,
  ) async {
    final food = FakeFoodClient(stores: _manyStores(3));
    await _pump(tester, food);

    await tester.drag(
      find.byType(CustomScrollView).first,
      const Offset(0, -1200),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('food-feed-end')), findsOneWidget);
    expect(food.storePages.where((page) => page > 1), isEmpty);
  });

  testWidgets('a failed page is retried only from the retry button', (
    tester,
  ) async {
    final food = _FailingSecondPageFoodClient(stores: _manyStores(25));
    await _pump(tester, food);

    final feed = find.byType(CustomScrollView).first;
    for (var i = 0; i < 8 && food.failedRequests == 0; i++) {
      await tester.drag(feed, const Offset(0, -1200));
      await tester.pumpAndSettle();
    }
    expect(food.failedRequests, 1);
    expect(find.byKey(const Key('food-feed-retry')), findsOneWidget);

    await tester.drag(feed, const Offset(0, 600));
    await tester.pumpAndSettle();
    await tester.drag(feed, const Offset(0, -600));
    await tester.pumpAndSettle();
    expect(food.failedRequests, 1);

    await tester.tap(find.byKey(const Key('food-feed-retry')));
    await tester.pumpAndSettle();
    expect(food.failedRequests, 2);
  });

  testWidgets('returning to the top does not refetch the home banners', (
    tester,
  ) async {
    final food = FakeFoodClient(stores: _manyStores(25));
    await _pump(tester, food);

    final banners = _bannerRepository(tester);
    final before = banners.listCalls;
    final firstPageLoads = food.storePages.where((page) => page == 1).length;

    final feed = find.byType(CustomScrollView).first;
    await tester.drag(feed, const Offset(0, -1600));
    await tester.pumpAndSettle();
    await tester.dragUntilVisible(
      find.byKey(const Key('food-search-entry')),
      feed,
      const Offset(0, 300),
    );
    await tester.pumpAndSettle();

    expect(banners.listCalls, before);
    expect(food.storePages.where((page) => page == 1).length, firstPageLoads);
  });

  testWidgets('pull-to-refresh reloads the home banners exactly once', (
    tester,
  ) async {
    final food = _GatedFoodClient(stores: _manyStores(25));
    await _pump(tester, food);

    final banners = _bannerRepository(tester);
    final before = banners.listCalls;

    food.gate = Completer<void>();
    await tester.fling(
      find.byType(CustomScrollView).first,
      const Offset(0, 400),
      1000,
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    food.gate!.complete();
    food.gate = null;
    await tester.pumpAndSettle();

    expect(banners.listCalls - before, 1);
  });
}

FakeHomeBannerRepository _bannerRepository(WidgetTester tester) {
  return Provider.of<HomeBannerRepository>(
    tester.element(find.byType(FoodStoreCard).first),
    listen: false,
  ) as FakeHomeBannerRepository;
}
