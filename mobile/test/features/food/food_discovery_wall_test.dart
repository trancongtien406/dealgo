import 'dart:async';

import 'package:dealgo/core/network/api_exception.dart';
import 'package:dealgo/features/activity/data/datasources/fake_history_client.dart';
import 'package:dealgo/features/activity/domain/entities/history_models.dart';
import 'package:dealgo/features/food/domain/entities/food_models.dart';
import 'package:dealgo/features/food/presentation/cubit/food_cart_cubit.dart';
import 'package:dealgo/features/promotion/domain/entities/available_voucher.dart';
import 'package:dealgo/features/promotion/domain/entities/voucher_quote.dart';
import 'package:dealgo/features/promotion/presentation/pages/vouchers_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/auth_test_harness.dart';
import '../../support/fake_food_client.dart';
import '../../support/fake_identity_client.dart';
import '../../support/fake_promotion_client.dart';

const _storeId = 'store-bun-bo';
const _orderId = 'order-1';

const _unavailable = ApiException(
  statusCode: 503,
  message: 'unavailable',
  errorCode: 'TEST_UNAVAILABLE',
);

AvailableVoucher foodVoucher({
  required String code,
  required String title,
  int valueVnd = 20000,
}) => AvailableVoucher(
  code: code,
  name: title,
  description: '',
  service: VoucherService.food,
  kind: VoucherDiscountKind.fixedAmount,
  discountValue: valueVnd,
  minOrderVnd: 50000,
  endsAt: DateTime(2030),
  usesLeft: 2,
);

HistoryItem completedFoodHistory({
  String id = _orderId,
  String storeName = 'Bún Bò Huế',
}) => HistoryItem(
  id: id,
  kind: HistoryKind.food,
  title: storeName,
  meta: '12:45 · 1 món',
  status: 'DELIVERED',
  amountVnd: 65000,
);

FoodOrderDetail completedOrder({String storeName = 'Bún Bò Huế'}) =>
    FoodOrderDetail(
      id: _orderId,
      status: 'DELIVERED',
      subtotalVnd: 55000,
      deliveryFareVnd: 10000,
      totalVnd: 65000,
      dropoff: const FoodDropoff(label: 'Nhà', lat: 10.77, lng: 106.7),
      storeName: storeName,
      storeId: _storeId,
      lines: const [
        FoodOrderLine(
          itemId: 'item-bun',
          name: 'Bún bò đặc biệt',
          unitPriceVnd: 55000,
          quantity: 1,
        ),
      ],
    );

FakeFoodClient foodWithOrder({String storeName = 'Bún Bò Huế'}) =>
    FakeFoodClient(
      orderDetail: completedOrder(storeName: storeName),
      details: const {
        _storeId: FoodStoreDetail(
          id: _storeId,
          name: 'Bún Bò Huế',
          items: [
            FoodMenuItem(
              id: 'item-bun',
              name: 'Bún bò đặc biệt',
              priceVnd: 55000,
              available: true,
            ),
          ],
        ),
      },
    );

class _GatedHistoryClient extends FakeHistoryClient {
  _GatedHistoryClient(this._gate, {super.food});

  final Future<void> _gate;

  @override
  Future<List<HistoryItem>> listFoodHistory(String accessToken) async {
    await _gate;
    return super.listFoodHistory(accessToken);
  }
}

Future<void> pumpDiscovery(
  WidgetTester tester, {
  required FakeFoodClient food,
  required FakePromotionClient promotions,
  FakeHistoryClient? history,
}) async {
  tester.view.physicalSize = const Size(400, 1600);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);

  await pumpSignedIn(
    tester,
    profile: customerProfile,
    foodClient: food,
    promotions: promotions,
    historyClient: history ?? FakeHistoryClient(food: []),
  );
  await tester.tap(find.text('Đồ ăn').first);
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('feed shows usable vouchers and the last completed order', (
    tester,
  ) async {
    await pumpDiscovery(
      tester,
      food: foodWithOrder(),
      promotions: FakePromotionClient(
        available: [foodVoucher(code: 'FOOD20', title: 'Giảm 20K')],
      ),
      history: FakeHistoryClient(food: [completedFoodHistory()]),
    );

    expect(find.byKey(const Key('food-voucher-wall')), findsOneWidget);
    expect(find.text('Giảm 20K'), findsWidgets);
    expect(find.byKey(const Key('food-reorder-strip')), findsOneWidget);
    expect(find.text('Đặt lại'), findsOneWidget);
  });

  testWidgets('feed hides both blocks when there is nothing to show', (
    tester,
  ) async {
    await pumpDiscovery(
      tester,
      food: FakeFoodClient(),
      promotions: FakePromotionClient(),
    );

    expect(find.byKey(const Key('food-voucher-wall')), findsNothing);
    expect(find.byKey(const Key('food-reorder-strip')), findsNothing);
  });

  testWidgets('both blocks hide when their loads fail', (tester) async {
    final promotions = FakePromotionClient()..error = _unavailable;
    await pumpDiscovery(
      tester,
      food: foodWithOrder()..orderError = _unavailable,
      promotions: promotions,
      history: FakeHistoryClient(food: [completedFoodHistory()]),
    );

    expect(find.byKey(const Key('food-voucher-wall')), findsNothing);
    expect(find.byKey(const Key('food-reorder-strip')), findsNothing);
  });

  testWidgets('the reorder strip survives a failed promotions load', (
    tester,
  ) async {
    await pumpDiscovery(
      tester,
      food: foodWithOrder(),
      promotions: FakePromotionClient()..error = _unavailable,
      history: FakeHistoryClient(food: [completedFoodHistory()]),
    );

    expect(find.byKey(const Key('food-voucher-wall')), findsNothing);
    expect(find.byKey(const Key('food-reorder-strip')), findsOneWidget);
  });

  testWidgets('the voucher wall survives a failed order load', (tester) async {
    await pumpDiscovery(
      tester,
      food: foodWithOrder()..orderError = _unavailable,
      promotions: FakePromotionClient(
        available: [foodVoucher(code: 'FOOD20', title: 'Giảm 20K')],
      ),
      history: FakeHistoryClient(food: [completedFoodHistory()]),
    );

    expect(find.byKey(const Key('food-voucher-wall')), findsOneWidget);
    expect(find.byKey(const Key('food-reorder-strip')), findsNothing);
  });

  testWidgets('the voucher wall opens the voucher list from "Xem tất cả"', (
    tester,
  ) async {
    await pumpDiscovery(
      tester,
      food: FakeFoodClient(),
      promotions: FakePromotionClient(
        available: [foodVoucher(code: 'FOOD20', title: 'Giảm 20K')],
      ),
    );

    final seeAll = find.byKey(const Key('food-voucher-wall-see-all'));
    expect(tester.getSize(seeAll).height, greaterThanOrEqualTo(48));
    expect(tester.getSize(seeAll).width, greaterThanOrEqualTo(48));

    await tester.tap(seeAll);
    await tester.pumpAndSettle();

    expect(find.byType(VouchersPage), findsOneWidget);
  });

  testWidgets('the reorder skeleton keeps the loaded strip height', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(400, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    final gate = Completer<void>();
    await pumpSignedIn(
      tester,
      profile: customerProfile,
      foodClient: foodWithOrder(),
      promotions: FakePromotionClient(),
      historyClient: _GatedHistoryClient(
        gate.future,
        food: [completedFoodHistory()],
      ),
    );
    await tester.tap(find.text('Đồ ăn').first);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    final skeleton = find.byKey(const Key('food-reorder-strip-skeleton'));
    expect(skeleton, findsOneWidget);
    final skeletonHeight = tester.getSize(skeleton).height;

    gate.complete();
    await tester.pumpAndSettle();

    final strip = find.byKey(const Key('food-reorder-strip'));
    expect(strip, findsOneWidget);
    expect(tester.getSize(strip).height, closeTo(skeletonHeight, 0.5));
  });

  testWidgets('the reorder strip refills the cart and opens checkout', (
    tester,
  ) async {
    await pumpDiscovery(
      tester,
      food: foodWithOrder(),
      promotions: FakePromotionClient(),
      history: FakeHistoryClient(food: [completedFoodHistory()]),
    );

    final cart = tester
        .element(find.byKey(const Key('food-reorder-strip')))
        .read<FoodCartCubit>();
    await tester.tap(find.byKey(const Key('food-reorder-strip-action')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('food-reorder-confirm')));
    await tester.pumpAndSettle();

    expect(cart.state.storeId, _storeId);
    expect(cart.state.lines.single.catalogItemId, 'item-bun');
    expect(cart.state.dropoffLabel, 'Nhà');
    expect(find.byKey(const Key('food-checkout-scroll')), findsOneWidget);
  });
}
