import 'package:dealgo/features/food/data/datasources/dio_food_remote_datasource.dart';
import 'package:dealgo/features/food/domain/entities/food_models.dart';
import 'package:dealgo/core/network/api_exception.dart';
import 'package:dealgo/features/identity/domain/entities/user_profile.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/auth_test_harness.dart';
import 'support/fake_food_client.dart';

const _merchantProfile = UserProfile(
  id: 'merchant-1',
  phone: '+84901110001',
  email: null,
  phoneVerifiedAt: '2026-10-13T16:00:00.000Z',
  emailVerifiedAt: null,
  grants: [RoleGrant(role: 'MERCHANT', status: 'ACTIVE')],
);

void main() {
  test('queue reads the success envelope', () {
    final orders = decodeMerchantQueue({
      'success': true,
      'data': [
        {
          'id': 'order-1',
          'storeId': 'store-1',
          'status': 'PLACED',
          'deliveryFareVnd': 25000,
          'subtotalVnd': 125000,
          'totalVnd': 150000,
          'dropoff': {'lat': 16.1, 'lng': 108.2, 'label': '456 Trần Hưng Đạo'},
          'lineCount': 3,
          'createdAt': '2026-10-14T02:20:00.000Z',
        },
      ],
    });
    expect(orders.single.status, 'PLACED');
    expect(orders.single.subtotalVnd, 125000);
    expect(orders.single.totalVnd, 150000);

    final update = decodeMerchantOrderUpdate({
      'success': true,
      'data': {
        'id': 'order-1',
        'status': 'PREPARING',
        'subtotalVnd': 125000,
        'deliveryFareVnd': 25000,
        'totalVnd': 150000,
        'lines': [
          {
            'itemId': 'bun',
            'name': 'Bún',
            'unitPriceVnd': 125000,
            'quantity': 1,
          },
        ],
      },
    });
    expect(update.status, 'PREPARING');
    expect(update.lineCount, 1);
    expect(update.totalVnd, 150000);
  });

  testWidgets('queue lists one PLACED order', (tester) async {
    final food = FakeFoodClient()..queueOrders = [_placedOrder()];
    await _openOrders(tester, food);

    expect(food.queueCalls, isNotEmpty);
    expect(food.queueCalls, everyElement('access-token'));
    expect(find.textContaining('Chờ Shop xác nhận'), findsWidgets);
    expect(find.text('456 Trần Hưng Đạo'), findsOneWidget);
    expect(find.textContaining('125.000đ'), findsWidgets);
    expect(find.text('150.000đ'), findsWidgets);
    expect(find.text('Chưa có đơn mới'), findsNothing);
  });

  testWidgets('empty list shows the empty state', (tester) async {
    final food = FakeFoodClient();
    await _openOrders(tester, food);

    expect(food.queueCalls, isNotEmpty);
    expect(find.text('Chưa có đơn mới'), findsOneWidget);
    expect(find.text('Đơn chờ xác nhận'), findsOneWidget);
    expect(find.text('0'), findsWidgets);
    expect(find.text('PLACED'), findsNothing);
    expect(find.text('Không tải được đơn hàng'), findsNothing);
  });

  testWidgets('accept sends the order id and shows PREPARING', (tester) async {
    final food = FakeFoodClient()..queueOrders = [_placedOrder()];
    await _openOrders(tester, food);
    await _openPlacedOrder(tester);
    await tester.tap(find.byKey(const Key('merchant-accept')));
    await tester.pumpAndSettle();

    expect(food.acceptCalls, ['order-placed-1']);
    expect(find.text('PREPARING'), findsWidgets);
    expect(find.text('Đang chuẩn bị'), findsWidgets);
    expect(find.text('Đơn đã được xử lý'), findsNothing);
    expect(find.textContaining('thành công'), findsNothing);
  });

  testWidgets('404 shows the conflict message and not success', (tester) async {
    final food = FakeFoodClient()
      ..queueOrders = [_placedOrder()]
      ..acceptError = const ApiException(
        statusCode: 404,
        message: 'Food order not found',
        errorCode: 'FOOD_ORDER_NOT_FOUND',
      );
    await _openOrders(tester, food);
    await _openPlacedOrder(tester);
    await tester.tap(find.byKey(const Key('merchant-accept')));
    await tester.pumpAndSettle();

    expect(food.acceptCalls, ['order-placed-1']);
    expect(find.text('Đơn đã được xử lý'), findsOneWidget);
    expect(
      find.text('Một nhân viên khác hoặc hệ thống đã xử lý đơn này trước bạn.'),
      findsOneWidget,
    );
    expect(find.text('PREPARING'), findsNothing);
    expect(find.text('Đang chuẩn bị'), findsNothing);
    expect(find.textContaining('thành công'), findsNothing);
    expect(find.text('125.000đ'), findsWidgets);
  });

  testWidgets('403 shows ineligible, not an empty queue', (tester) async {
    final food = FakeFoodClient()
      ..queueOrders = [
        _placedOrder(dropoff: 'Không được hiện như hàng đợi trống'),
      ]
      ..queueError = const ApiException(
        statusCode: 403,
        message: 'An active role is required',
        errorCode: 'ROLE_NOT_ACTIVE',
      );
    await _openOrders(tester, food);

    expect(food.queueCalls, isNotEmpty);
    expect(find.text('Cửa hàng chưa được phép nhận đơn'), findsWidgets);
    expect(find.text('Chưa có đơn mới'), findsNothing);
    expect(find.text('Không được hiện như hàng đợi trống'), findsNothing);
    expect(find.text('PLACED'), findsNothing);
  });

  testWidgets(
    'network failure shows the queue error and does not move the order',
    (tester) async {
      final food = FakeFoodClient()
        ..queueOrders = [_placedOrder()]
        ..acceptError = Exception('offline');
      await _openOrders(tester, food);
      await _openPlacedOrder(tester);
      await tester.tap(find.byKey(const Key('merchant-accept')));
      await tester.pumpAndSettle();

      expect(food.acceptCalls, ['order-placed-1']);
      expect(find.text('Không tải được đơn hàng'), findsOneWidget);
      expect(
        find.text(
          'Không coi lỗi mạng là "0 đơn"; không tự chuyển sang chế độ tạm đóng.',
        ),
        findsOneWidget,
      );
      expect(find.text('PREPARING'), findsNothing);
      expect(find.text('Đang chuẩn bị'), findsNothing);
      expect(find.textContaining('thành công'), findsNothing);
      expect(find.text('Chưa có đơn mới'), findsNothing);
    },
  );
}

Future<void> _openOrders(WidgetTester tester, FakeFoodClient food) async {
  await pumpSignedIn(tester, profile: _merchantProfile, foodClient: food);
  await tester.tap(navLabel('Đơn hàng'));
  await tester.pumpAndSettle();
}

Future<void> _openPlacedOrder(WidgetTester tester) async {
  final card = find.byKey(const Key('merchant-order-order-placed-1'));
  await tester.ensureVisible(card);
  await tester.tap(card);
  await tester.pumpAndSettle();
  final accept = find.byKey(const Key('merchant-accept'));
  await tester.ensureVisible(accept);
}

MerchantQueueOrder _placedOrder({String dropoff = '456 Trần Hưng Đạo'}) {
  return MerchantQueueOrder(
    id: 'order-placed-1',
    storeId: 'store-1',
    status: 'PLACED',
    deliveryFareVnd: 25000,
    subtotalVnd: 125000,
    totalVnd: 150000,
    dropoff: FoodDropoff(lat: 16.1, lng: 108.22, label: dropoff),
    lineCount: 3,
    createdAt: '2026-10-14T02:20:00.000Z',
  );
}
