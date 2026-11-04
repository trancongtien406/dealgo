import 'package:dealgo/features/food/domain/entities/food_models.dart';
import 'package:dealgo/features/food/presentation/widgets/food_badges.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/auth_test_harness.dart';
import '../../support/fake_food_client.dart';
import '../../support/fake_identity_client.dart';

const _storeId = 'store-dishes';
const _longName = 'Cơm sườn bì chả đặc biệt thêm trứng ốp la';

FoodStoreSummary _storeFor() => const FoodStoreSummary(
  id: _storeId,
  name: 'Cơm Tấm Bà Chiến — Quận 1',
  category: 'rice',
  featuredItems: [
    FoodFeaturedItem(
      id: 'dish-long',
      name: _longName,
      priceVnd: 65000,
      originalPriceVnd: 75000,
      soldCount: 386,
    ),
    FoodFeaturedItem(id: 'dish-short', name: 'Trà đá', priceVnd: 5000),
    FoodFeaturedItem(
      id: 'dish-plain',
      name: 'Bún bò đặc biệt',
      priceVnd: 60000,
      originalPriceVnd: 70000,
      soldCount: 412,
    ),
  ],
);

void main() {
  testWidgets('dish cards in a strip share one height and badge the saving', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1206, 2622);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    await pumpSignedIn(
      tester,
      profile: customerProfile,
      foodClient: FakeFoodClient(stores: [_storeFor()]),
      initialLocation: '/customer',
    );
    await tester.tap(navLabel('Mua'));
    await tester.pumpAndSettle();

    final cards = find.byWidgetPredicate(
      (widget) => widget.key is ValueKey<String> &&
          (widget.key! as ValueKey<String>).value.startsWith('food-dish-card-'),
    );
    for (var i = 0; i < 8 && cards.evaluate().isEmpty; i++) {
      await tester.drag(find.byType(CustomScrollView).first, const Offset(0, -300));
      await tester.pumpAndSettle();
    }
    expect(cards, findsNWidgets(2));

    final heights = {
      for (final element in cards.evaluate())
        (element.renderObject! as RenderBox).size.height,
    };
    expect(heights, hasLength(1), reason: 'cards in a strip must be even');

    final discounted = find.byKey(const Key('food-dish-card-dish-long'));
    final card = tester.getRect(discounted);
    final pill = find.descendant(
      of: discounted,
      matching: find.byType(FoodDiscountPill),
    );
    expect(pill, findsOneWidget);
    final pillRect = tester.getRect(pill);
    expect(
      pillRect.top,
      lessThan(card.top + 40),
      reason: 'the saving belongs on the photo, not under the price',
    );

    // The struck-through list price stays next to the current price.
    expect(
      find.descendant(of: discounted, matching: find.text('70.000đ')),
      findsNothing,
    );
    expect(
      find.descendant(of: discounted, matching: find.text('75.000đ')),
      findsOneWidget,
    );
  });
}
