import 'package:dealgo/features/food/data/datasources/dio_food_remote_datasource.dart';
import 'package:dealgo/features/food/domain/entities/food_models.dart';
import 'package:dealgo/core/network/api_exception.dart';
import 'package:dealgo/features/ride/domain/entities/ride_models.dart';
import 'package:dealgo/features/ride/domain/entities/ride_money.dart';
import 'package:dealgo/features/ride/presentation/utils/ride_routes.dart';
import 'package:dealgo/features/food/presentation/utils/food_routes.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'support/auth_test_harness.dart';
import 'support/fake_food_client.dart';
import 'support/fake_identity_client.dart';
import 'support/fake_ride_client.dart';

void main() {
  test('food tracking stage follows the server status', () {
    expect(foodTrackingStage('PLACED'), FoodTrackingStage.preparing);
    expect(foodTrackingStage('PREPARING'), FoodTrackingStage.preparing);
    expect(foodTrackingStage('READY'), FoodTrackingStage.onTheWay);
    expect(foodTrackingStage('ASSIGNED'), FoodTrackingStage.onTheWay);
    expect(foodTrackingTitle(FoodTrackingStage.preparing), 'Đang chuẩn bị món');
    expect(foodTrackingTitle(FoodTrackingStage.onTheWay), 'Đơn đang được giao');

    final order = decodeFoodOrderDetail({
      'success': true,
      'data': {
        'id': 'order-1',
        'status': 'PREPARING',
        'subtotalVnd': 125000,
        'deliveryFareVnd': 25000,
        'totalVnd': 150000,
        'dropoff': {'lat': 16.1, 'lng': 108.2, 'label': 'Sơn Trà'},
        'lines': [
          {
            'itemId': 'item-bun',
            'name': 'Bún bò',
            'unitPriceVnd': 125000,
            'quantity': 1,
          },
        ],
      },
    });
    expect(order.stage, FoodTrackingStage.preparing);
    expect(order.dropoff.label, 'Sơn Trà');
    expect(order.totalVnd, 150000);
  });

  testWidgets('NEGOTIATING ride shows the matching screen', (tester) async {
    final rides = FakeRideClient()..onGet = (_) => _ride();
    await _pumpCustomer(tester, rides: rides);

    await _push(tester, RideRoutes.matching('ride-1'));

    expect(find.text('Đang nhận báo giá'), findsOneWidget);
    expect(find.text('Đang chờ tài xế chào giá...'), findsOneWidget);
    expect(find.text(rideVehicleLabel), findsWidgets);
    expect(find.textContaining('Xe 4 chỗ'), findsNothing);
    expect(find.text('Chưa tìm được tài xế'), findsNothing);
  });

  testWidgets('EXPIRED ride shows the timeout copy', (tester) async {
    final rides = FakeRideClient()
      ..onGet = (_) => _ride(status: RideStatus.expired);
    await _pumpCustomer(tester, rides: rides);

    await _push(tester, RideRoutes.matching('ride-1'));

    expect(find.text('Chưa tìm được tài xế'), findsOneWidget);
    expect(find.textContaining('TIMEOUT'), findsOneWidget);
    expect(find.text('Đang chờ tài xế chào giá...'), findsNothing);
  });

  testWidgets('a past expiresAt shows the timeout copy', (tester) async {
    final rides = FakeRideClient()
      ..onGet = (_) => _ride(expiresAt: '2020-01-01T00:00:00.000Z');
    await _pumpCustomer(tester, rides: rides);

    await _push(tester, RideRoutes.matching('ride-1'));

    expect(find.text('Chưa tìm được tài xế'), findsOneWidget);
  });

  testWidgets('ASSIGNED ride shows agreedFareVnd on the receipt', (
    tester,
  ) async {
    final rides = FakeRideClient()
      ..onGet = (_) => _ride(
        status: RideStatus.assigned,
        agreedFareVnd: 45000,
        assignedDriverId: 'driver-hung',
      );
    await _pumpCustomer(tester, rides: rides);

    await _push(tester, RideRoutes.tracking('ride-1'));

    expect(find.text('Tài xế đang đến đón'), findsOneWidget);
    expect(find.text('45.000đ'), findsWidgets);
    expect(find.text('Nguyễn Văn Hùng'), findsOneWidget);
    expect(find.text('Đang di chuyển tới điểm đón'), findsOneWidget);
    expect(find.byKey(const Key('ride-pickup-code')), findsOneWidget);

    await tester.tap(find.byKey(const Key('ride-open-receipt')));
    await tester.pumpAndSettle();

    expect(find.text('Biên nhận chuyến đi'), findsOneWidget);
    expect(find.text('Chuyến đi hoàn tất!'), findsOneWidget);
    expect(find.byKey(const Key('ride-receipt-fare')), findsOneWidget);
    expect(
      tester.widget<Text>(find.byKey(const Key('ride-receipt-fare'))).data,
      '45.000đ',
    );
    expect(find.text('Phí nền tảng'), findsNothing);
    expect(find.text('Tiền tip'), findsNothing);
    expect(find.textContaining('Xe 4 chỗ'), findsWidgets);
  });

  testWidgets(
    'a failed ride refresh shows the offline copy and not a success arrival',
    (tester) async {
      final rides = FakeRideClient()
        ..onGet = (_) =>
            _ride(status: RideStatus.assigned, agreedFareVnd: 45000);
      await _pumpCustomer(tester, rides: rides);
      await _push(tester, RideRoutes.tracking('ride-1'));
      expect(find.text('Tài xế đang đến đón'), findsOneWidget);

      rides.getError = const ApiException(
        statusCode: 0,
        message: 'Không thể kết nối máy chủ',
        errorCode: 'NETWORK_ERROR',
      );
      await tester.tap(find.byKey(const Key('ride-tracking-retry')));
      await tester.pumpAndSettle();

      expect(find.text('Tạm mất kết nối vị trí'), findsOneWidget);
      expect(find.text('Tài xế đang đến đón'), findsNothing);
      expect(find.text('Tài xế đã đến điểm đón'), findsNothing);
      expect(find.text('Tài xế đã đến'), findsNothing);
    },
  );

  testWidgets(
    'food PREPARING shows the preparing state and a failed refresh reconnects',
    (tester) async {
      final food = FakeFoodClient()
        ..orderDetail = const FoodOrderDetail(
          id: 'order-1',
          status: 'PREPARING',
          subtotalVnd: 125000,
          deliveryFareVnd: 25000,
          totalVnd: 150000,
          dropoff: FoodDropoff(lat: 16.1, lng: 108.2, label: 'Sơn Trà'),
          lines: [
            FoodOrderLine(
              itemId: 'item-bun',
              name: 'Bún bò',
              unitPriceVnd: 125000,
              quantity: 1,
            ),
          ],
        );
      await _pumpCustomer(tester, food: food);
      await _push(tester, FoodRoutes.order('order-1'));

      expect(find.text('Đang chuẩn bị món'), findsOneWidget);
      expect(find.text('150.000đ'), findsOneWidget);
      expect(find.text('Đơn đang được giao'), findsNothing);
      expect(find.text('Trần Minh Anh'), findsNothing);
      expect(food.orderReads, ['order-1']);

      food.orderError = const ApiException(
        statusCode: 0,
        message: 'Không thể kết nối máy chủ',
        errorCode: 'NETWORK_ERROR',
      );
      await tester.tap(find.byKey(const Key('food-tracking-retry')));
      await tester.pumpAndSettle();

      expect(find.text('Đang kết nối lại...'), findsOneWidget);
      expect(find.text('Đang chuẩn bị món'), findsNothing);
      expect(find.text('Đơn đang được giao'), findsNothing);
      expect(find.text('150.000đ'), findsOneWidget);
    },
  );
}

Future<void> _pumpCustomer(
  WidgetTester tester, {
  FakeRideClient? rides,
  FakeFoodClient? food,
}) async {
  await tester.binding.setSurfaceSize(const Size(400, 1800));
  addTearDown(() => tester.binding.setSurfaceSize(null));
  await pumpSignedIn(
    tester,
    profile: customerProfile,
    rideClient: rides,
    foodClient: food,
  );
}

Future<void> _push(WidgetTester tester, String location) async {
  final context = tester.element(find.byType(Scaffold).first);
  GoRouter.of(context).push(location);
  await tester.pumpAndSettle();
}

RideView _ride({
  RideStatus status = RideStatus.negotiating,
  int? agreedFareVnd,
  String? assignedDriverId,
  String expiresAt = '2030-01-01T00:00:00.000Z',
}) {
  return RideView(
    id: 'ride-1',
    status: status,
    pickup: const RidePoint(
      lat: rideSamplePickupLat,
      lng: rideSamplePickupLng,
      label: rideSamplePickupLabel,
    ),
    dropoff: const RidePoint(
      lat: rideSampleDropoffLat,
      lng: rideSampleDropoffLng,
      label: rideSampleDropoffLabel,
    ),
    offeredFareVnd: 42000,
    referenceFareVnd: 40000,
    agreedFareVnd: agreedFareVnd,
    assignedDriverId: assignedDriverId,
    selectedOfferId: null,
    expiresAt: expiresAt,
    offers: const [],
  );
}
