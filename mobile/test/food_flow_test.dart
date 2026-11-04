import 'package:dealgo/features/pricing/data/pricing_remote_datasource.dart';
import 'package:dealgo/features/food/data/datasources/dio_food_remote_datasource.dart';
import 'package:dealgo/features/food/data/datasources/food_remote_datasource.dart';
import 'package:dealgo/features/food/data/models/place_food_order_body.dart';
import 'package:dealgo/features/food/domain/params/place_food_order_params.dart';
import 'package:dealgo/features/food/domain/entities/food_models.dart';
import 'package:dealgo/features/food/presentation/cubit/food_cart_cubit.dart';
import 'package:dealgo/core/network/api_exception.dart';
import 'package:dealgo/features/food/presentation/widgets/food_checkout_widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:dealgo/features/food/presentation/utils/food_routes.dart';

import 'support/auth_test_harness.dart';
import 'support/fake_food_client.dart';
import 'support/fake_identity_client.dart';

const _storeId = 'store-bun-bo';
const _bunId = 'item-bun';

void main() {
  testWidgets('the shop banner is tappable as a whole', (tester) async {
    await pumpSignedIn(tester, profile: customerProfile);
    await tester.tap(navLabel('Mua'));
    await tester.pumpAndSettle();

    final banner = find.byKey(const Key('food-banner'));
    expect(banner, findsOneWidget);
    expect(tester.widget<InkWell>(banner).onTap, isNotNull);
    await tester.tapAt(tester.getTopLeft(banner) + const Offset(24, 24));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });

  test(
    'store list reads array or items payload and orders keep server subtotal',
    () {
      final legacy = decodeFoodStoreList({
        'success': true,
        'statusCode': 200,
        'message': 'OK',
        'data': [
          {'id': _storeId, 'name': 'Bún Bò Huế', 'ownerId': 'owner'},
        ],
      });
      expect(legacy.single.name, 'Bún Bò Huế');

      final paged = decodeFoodStoreList({
        'success': true,
        'statusCode': 200,
        'message': 'OK',
        'data': {
          'items': [
            {
              'id': _storeId,
              'name': 'Bún Bò Huế',
              'ownerId': 'owner',
              'distanceKm': 1.2,
            },
          ],
        },
      });
      expect(paged.single.name, 'Bún Bò Huế');
      expect(paged.single.distanceKm, 1.2);

      final order = decodePlacedFoodOrder({
        'success': true,
        'data': {
          'id': 'order-1',
          'status': 'PLACED',
          'subtotalVnd': 61000,
          'deliveryFareVnd': 25000,
          'totalVnd': 86000,
          'lines': [
            {
              'itemId': _bunId,
              'name': 'Bún bò đặc biệt',
              'unitPriceVnd': 61000,
              'quantity': 1,
            },
          ],
        },
      });
      expect(order.subtotalVnd, 61000);
      expect(order.totalVnd, 86000);
    },
  );

  test('place request does not send a client total', () {
    final json = PlaceFoodOrderBody.fromParams(
      PlaceFoodRequest(
        accessToken: 'token',
        idempotencyKey: 'idem-food-1',
        storeId: _storeId,
        items: const [FoodOrderItem(itemId: _bunId, quantity: 1)],
        dropoff: const FoodDropoff(lat: 16.1, lng: 108.2, label: 'Sơn Trà'),
        deliveryFareVnd: 25000,
      ),
    ).toJson();
    expect(json.containsKey('total'), isFalse);
    expect(json.containsKey('totalVnd'), isFalse);
    expect(json.containsKey('subtotalVnd'), isFalse);
    expect(json['deliveryFareVnd'], 25000);
  });

  test('cart keeps items from a single store', () {
    final cart = FoodCartCubit();
    addTearDown(cart.close);
    cart.addItem(
      storeId: 'a',
      storeName: 'Quán A',
      item: const FoodMenuItem(
        id: 'a1',
        name: 'Món A',
        priceVnd: 10000,
        available: true,
      ),
    );
    cart.addItem(
      storeId: 'b',
      storeName: 'Bún Bò Huế',
      item: const FoodMenuItem(
        id: _bunId,
        name: 'Bún bò đặc biệt',
        priceVnd: 60000,
        available: true,
      ),
    );
    expect(cart.state.storeId, 'b');
    expect(cart.state.lines.single.itemId, _bunId);
    expect(cart.state.subtotalVnd, 60000);
  });

  testWidgets('discovery lists a store from the client', (tester) async {
    await tester.binding.setSurfaceSize(const Size(400, 1400));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final food = _catalogClient();
    await pumpSignedIn(tester, profile: customerProfile, foodClient: food);

    await tester.tap(find.text('Đồ ăn').first);
    await tester.pumpAndSettle();

    expect(find.text('Gần bạn'), findsOneWidget);
    expect(find.text('Bún Bò Huế'), findsWidgets);
    expect(
      find.byWidgetPredicate(
        (widget) =>
            widget is Semantics &&
            widget.properties.label == 'Mua' &&
            widget.properties.selected == true,
      ),
      findsWidgets,
    );

    await tapFoodStoreCard(tester, _storeId);
    await tester.pumpAndSettle();
    expect(find.text('Chi tiết quán'), findsOneWidget);
    expect(find.text('Bún bò đặc biệt'), findsOneWidget);
    expect(find.text('60.000đ'), findsWidgets);
  });

  testWidgets('checkout shows the server subtotal', (tester) async {
    await tester.binding.setSurfaceSize(const Size(400, 1600));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final food = _catalogClient()
      ..placedOrder = const PlacedFoodOrder(
        id: 'order-1',
        status: 'PLACED',
        subtotalVnd: 61000,
        deliveryFareVnd: 25000,
        totalVnd: 86000,
        lines: [
          FoodOrderLine(
            itemId: _bunId,
            name: 'Bún bò đặc biệt',
            unitPriceVnd: 61000,
            quantity: 1,
          ),
        ],
      );
    await _openCheckout(tester, food);

    await tester.tap(find.byKey(const Key('food-place-order')));
    await tester.pumpAndSettle();

    expect(find.text('61.000đ'), findsOneWidget);
    expect(find.text('Giá đã thay đổi'), findsOneWidget);
    expect(food.placeCalls, hasLength(1));
    final request = food.placeCalls.single;
    expect(request.deliveryFareVnd, 25000);
    expect(
      PlaceFoodOrderBody.fromParams(request).toJson().containsKey('totalVnd'),
      isFalse,
    );
    expect(request.idempotencyKey.length, inInclusiveRange(8, 200));
    expect(request.items.single.quantity, 1);
  });

  testWidgets('failed client shows offline and does not claim success', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(400, 1600));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final food = _catalogClient()
      ..placeError = const ApiException(
        statusCode: 0,
        message: 'Không thể kết nối máy chủ',
        errorCode: 'NETWORK_ERROR',
      );
    await _openCheckout(tester, food);

    await tester.tap(find.byKey(const Key('food-place-order')));
    await tester.pumpAndSettle();

    expect(find.text('Bạn đang ngoại tuyến'), findsOneWidget);
    expect(find.text('Đặt hàng thành công'), findsNothing);
    expect(find.textContaining('thành công'), findsNothing);
    expect(food.placeCalls, hasLength(1));
    final key = food.placeCalls.single.idempotencyKey;

    food.placeError = null;
    food.placedOrder = const PlacedFoodOrder(
      id: 'order-1',
      status: 'PLACED',
      subtotalVnd: 61000,
      deliveryFareVnd: 25000,
      totalVnd: 86000,
      lines: [
        FoodOrderLine(
          itemId: _bunId,
          name: 'Bún bò đặc biệt',
          unitPriceVnd: 61000,
          quantity: 1,
        ),
      ],
    );
    await tester.tap(find.byKey(const Key('food-retry-order')));
    await tester.pumpAndSettle();

    expect(food.placeCalls, hasLength(2));
    expect(food.placeCalls[1].idempotencyKey, key);
    expect(find.text('61.000đ'), findsOneWidget);
    expect(find.text('Bạn đang ngoại tuyến'), findsNothing);
  });

  testWidgets('checkout: the sticky order bar never covers the last section', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(400, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await _openCheckout(tester, _catalogClient());
    // The body no longer extends under the bar (extendBody hid the payment
    // tile and swallowed its taps): the scroll view ends above the bar.
    final scrollBottom = tester
        .getRect(find.byKey(const Key('food-checkout-scroll')))
        .bottom;
    final barTop = tester.getRect(find.byType(CheckoutActions)).top;
    expect(scrollBottom, lessThanOrEqualTo(barTop + 0.5));
  });

  testWidgets(
    'QA C1/C2: after ordering the cart is empty and back never returns to checkout',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(400, 1600));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final food = _catalogClient()
        ..placedOrder = const PlacedFoodOrder(
          id: 'order-1',
          status: 'PLACED',
          subtotalVnd: 60000,
          deliveryFareVnd: 25000,
          totalVnd: 85000,
          lines: [
            FoodOrderLine(
              itemId: _bunId,
              name: 'Bún bò đặc biệt',
              unitPriceVnd: 60000,
              quantity: 1,
            ),
          ],
        );
      await _openCheckout(tester, food);
      await tester.tap(find.byKey(const Key('food-place-order')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('food-order-success-title')), findsOneWidget);
      final ctx = tester.element(
        find.byKey(const Key('food-order-success-title')),
      );
      expect(ctx.read<FoodCartCubit>().state.lines, isEmpty);

      await tester.tap(find.byKey(const Key('food-track-order')));
      await tester.pumpAndSettle();
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('food-place-order')), findsNothing);
      expect(find.byKey(const Key('food-checkout-empty')), findsNothing);
    },
  );

  testWidgets('empty checkout shows clear empty state and back-to-menu CTA', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(400, 1600));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final food = _catalogClient();
    await pumpSignedIn(
      tester,
      profile: customerProfile,
      foodClient: food,
      pricing: FakePricingRemoteDataSource(deliveryFareVnd: 25000),
    );
    final context = tester.element(find.byType(Scaffold).first);
    GoRouter.of(context).push(FoodRoutes.checkout);
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('food-checkout-empty')), findsOneWidget);
    expect(find.text('Giỏ hàng trống'), findsOneWidget);
    expect(find.text('Chưa có món.'), findsOneWidget);
    expect(find.byKey(const Key('state-view-action')), findsOneWidget);
    expect(find.text('Quay lại thực đơn'), findsOneWidget);
    expect(find.byKey(const Key('food-place-order')), findsNothing);
    expect(find.textContaining('Đặt hàng · 0đ'), findsNothing);
  });
}

FakeFoodClient _catalogClient() {
  const item = FoodMenuItem(
    id: _bunId,
    name: 'Bún bò đặc biệt',
    priceVnd: 60000,
    available: true,
  );
  return FakeFoodClient(
    stores: const [FoodStoreSummary(id: _storeId, name: 'Bún Bò Huế')],
    details: const {
      _storeId: FoodStoreDetail(
        id: _storeId,
        name: 'Bún Bò Huế',
        items: [item],
      ),
    },
  );
}

Future<void> _openCheckout(WidgetTester tester, FakeFoodClient food) async {
  await pumpSignedIn(
    tester,
    profile: customerProfile,
    foodClient: food,
    pricing: FakePricingRemoteDataSource(deliveryFareVnd: 25000),
  );
  await tester.tap(navLabel('Mua'));
  await tester.pumpAndSettle();
  await tapFoodStoreCard(tester, _storeId);
  final addItem = find.byKey(const Key('food-add-$_bunId'));
  await tester.ensureVisible(addItem);
  await tester.pumpAndSettle();
  await tester.tap(addItem);
  await tester.pumpAndSettle();
  final optionsAdd = find.byKey(const Key('food-options-add'));
  if (optionsAdd.evaluate().isNotEmpty) {
    await tester.tap(optionsAdd);
    await tester.pumpAndSettle();
  }
  await tester.tap(find.text('Xem giỏ hàng'));
  await tester.pumpAndSettle();
  await chooseDeliveryAddress(tester);
  expect(find.text('60.000đ'), findsWidgets);
  expect(find.text('25.000đ'), findsWidgets);
}

Future<void> tapFoodStoreCard(WidgetTester tester, String storeId) async {
  final card = find.byKey(Key('food-store-card-$storeId'));
  final scrollable = find.byType(Scrollable).first;
  await tester.scrollUntilVisible(card, 200, scrollable: scrollable);
  await tester.pumpAndSettle();
  final viewHeight =
      tester.view.physicalSize.height / tester.view.devicePixelRatio;
  final center = tester.getCenter(card);
  if (center.dy > viewHeight - 140) {
    await tester.drag(scrollable, Offset(0, viewHeight - 140 - center.dy));
    await tester.pumpAndSettle();
  }
  await tester.tap(card);
  await tester.pumpAndSettle();
}
