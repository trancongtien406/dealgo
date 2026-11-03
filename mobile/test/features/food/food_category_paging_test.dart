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

    expect(food.storeSearches.last, 'bún');
    expect(food.storeSorts.last, 'distance');

    await tester.tap(find.byKey(const Key('food-search-sort-rating')));
    await tester.pumpAndSettle();

    expect(food.storeSorts.last, 'rating');
    expect(food.storeSearches.last, 'bún');
  });
}
