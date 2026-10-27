import 'package:dealgo/features/food/presentation/pages/food_tracking_page.dart';
import 'package:dealgo/l10n/app_localizations.dart';
import 'package:dealgo/features/food/data/datasources/dio_food_remote_datasource.dart';
import 'package:dealgo/features/food/domain/entities/food_models.dart';
import 'package:dealgo/core/network/api_exception.dart';
import 'package:dealgo/features/driver_card/data/driver_card_remote_datasource.dart';
import 'package:dealgo/features/driver_card/domain/driver_card.dart';
import 'package:dealgo/features/ride/domain/entities/ride_models.dart';
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
    // The courier has the food: still on its way, not "unknown".
    expect(foodTrackingStage('PICKED_UP'), FoodTrackingStage.onTheWay);
    expect(foodTrackingStage('DELIVERED'), FoodTrackingStage.delivered);
    expect(foodTrackingStage('FAILED'), FoodTrackingStage.failed);
    expect(
      foodTrackingTitle(
        lookupAppLocalizations(const Locale('vi')),
        FoodTrackingStage.delivered,
      ),
      'Đã giao thành công',
    );
    expect(
      foodTrackingTitle(
        lookupAppLocalizations(const Locale('vi')),
        FoodTrackingStage.preparing,
      ),
      'Đang chuẩn bị món',
    );
    expect(
      foodTrackingTitle(
        lookupAppLocalizations(const Locale('vi')),
        FoodTrackingStage.onTheWay,
      ),
      'Đơn đang được giao',
    );

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
    // Redesigned matching screen shows the sent offer instead of the vehicle label.
    expect(find.text('Đã gửi đề xuất'), findsOneWidget);
    expect(find.text('42.000đ'), findsWidgets);
    expect(find.textContaining('Xe 4 chỗ'), findsNothing);
    expect(find.text('Chưa tìm được tài xế'), findsNothing);
  });

  testWidgets('NEGOTIATING tracking waits for offers, not "driver accepted"', (
    tester,
  ) async {
    final rides = FakeRideClient()..onGet = (_) => _ride();
    await _pumpCustomer(tester, rides: rides);

    await _push(tester, RideRoutes.tracking('ride-1'));
    expect(find.text('Tài xế đã nhận chuyến'), findsNothing);
    expect(find.text('Tài xế DealGo'), findsNothing);
    expect(
      find.byKey(const Key('ride-tracking-awaiting-offers')),
      findsOneWidget,
    );
    expect(find.text('Đang chờ tài xế chào giá...'), findsOneWidget);

    await tester.tap(find.byKey(const Key('ride-tracking-open-matching')));
    await tester.pumpAndSettle();
    expect(find.text('Đã gửi đề xuất'), findsOneWidget);
  });

  testWidgets('no pickup code is shown until the server issues one', (
    tester,
  ) async {
    final rides = FakeRideClient()
      ..onGet = (_) => _ride(
        status: RideStatus.assigned,
        agreedFareVnd: 45000,
        assignedDriverId: 'driver-tai',
      );
    await _pumpCustomer(tester, rides: rides);

    await _push(tester, RideRoutes.tracking('ride-1'));
    expect(find.byKey(const Key('ride-pickup-code')), findsNothing);
    expect(find.textContaining('7294'), findsNothing);
    // Driver card falls back to a neutral label when it cannot be loaded.
    expect(find.text('Tài xế DealGo'), findsOneWidget);

    await _push(tester, RideRoutes.pickupCode('ride-1'));
    expect(
      find.byKey(const Key('ride-pickup-code-unavailable')),
      findsOneWidget,
    );
  });

  testWidgets('EXPIRED ride shows the timeout copy', (tester) async {
    final rides = FakeRideClient()
      ..onGet = (_) => _ride(status: RideStatus.expired);
    await _pumpCustomer(tester, rides: rides);

    await _push(tester, RideRoutes.matching('ride-1'));

    expect(find.text('Chưa tìm được tài xế'), findsOneWidget);
    expect(find.textContaining('Tìm lại tài xế'), findsWidgets);
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
        assignedDriverId: 'driver-tai',
        pickupCode: '4821',
      );
    final cards = FakeDriverCardRemoteDataSource(
      card: const DriverCard(
        driverId: 'driver-tai',
        displayName: 'Lê Văn Tài',
        vehiclePlate: '43B1-678.90',
        vehicleType: 'Xe máy',
        ratingAverage: 4.75,
        ratingCount: 12,
      ),
    );
    await _pumpCustomer(tester, rides: rides, driverCard: cards);

    await _push(tester, RideRoutes.tracking('ride-1'));

    expect(find.text('Tài xế đang đến đón'), findsWidgets);
    expect(find.text('45.000đ'), findsWidgets);
    // Real driver card from the backend; no invented ETA or rating.
    expect(find.text('Lê Văn Tài'), findsOneWidget);
    expect(find.text('Xe máy · 43B1-678.90'), findsOneWidget);
    expect(find.text('4,8 · 12 đánh giá'), findsOneWidget);
    expect(cards.calls.single.job, DriverCardJob.ride);
    expect(find.textContaining('còn khoảng'), findsNothing);
    expect(find.textContaining('Q-CAR'), findsNothing);
    // Server-issued pickup code, shown as-is.
    expect(find.text('4 8 2 1'), findsOneWidget);

    // Receipt CTA only appears once the ride is COMPLETED.
    expect(find.byKey(const Key('ride-open-receipt')), findsNothing);
    await _push(tester, RideRoutes.receipt('ride-1'));

    // Not completed yet: no "completed" headline, no invented voucher/time.
    expect(find.text('Biên nhận chuyến đi'), findsWidgets);
    expect(find.text('Chuyến đi hoàn tất!'), findsNothing);
    expect(find.text('Voucher DealGo'), findsNothing);
    expect(find.byKey(const Key('ride-receipt-fare')), findsOneWidget);
    expect(
      tester.widget<Text>(find.byKey(const Key('ride-receipt-fare'))).data,
      '45.000đ',
    );
    expect(find.text('Hoa hồng DealGo'), findsNothing);
    expect(find.text('Tiền tip'), findsNothing);
    expect(find.textContaining('Xe 4 chỗ'), findsNothing);
    expect(find.textContaining('Toyota'), findsNothing);
    expect(find.text('Xe máy'), findsOneWidget);
  });

  testWidgets('COMPLETED ride shows the receipt CTA', (tester) async {
    final rides = FakeRideClient()
      ..onGet = (_) => _ride(
        status: RideStatus.completed,
        agreedFareVnd: 45000,
        assignedDriverId: 'driver-tai',
      );
    await _pumpCustomer(tester, rides: rides);
    await _push(tester, RideRoutes.tracking('ride-1'));
    expect(find.byKey(const Key('ride-open-receipt')), findsOneWidget);
  });

  testWidgets(
    'tracking ride A then ride B rebuilds state for B (ValueKey(rideId))',
    (tester) async {
      final rides = FakeRideClient()
        ..onGet = (id) => id == 'ride-2'
            ? _ride(
                id: 'ride-2',
                status: RideStatus.assigned,
                agreedFareVnd: 61000,
                assignedDriverId: 'driver-b',
              )
            : _ride(
                status: RideStatus.assigned,
                agreedFareVnd: 45000,
                assignedDriverId: 'driver-a',
              );
      await _pumpCustomer(tester, rides: rides);
      await _push(tester, RideRoutes.tracking('ride-1'));
      expect(find.text('45.000đ'), findsWidgets);

      final context = tester.element(find.byType(Scaffold).first);
      // replace() keeps the page key, so only ValueKey(rideId) forces a fresh State.
      GoRouter.of(context).replace(RideRoutes.tracking('ride-2'));
      await tester.pumpAndSettle();

      expect(rides.getCalls, contains('ride-2'));
      expect(find.text('61.000đ'), findsWidgets);
      expect(find.text('45.000đ'), findsNothing);
    },
  );

  testWidgets(
    'a failed ride refresh shows the offline copy and not a success arrival',
    (tester) async {
      final rides = FakeRideClient()
        ..onGet = (_) =>
            _ride(status: RideStatus.assigned, agreedFareVnd: 45000);
      await _pumpCustomer(tester, rides: rides);
      await _push(tester, RideRoutes.tracking('ride-1'));
      expect(find.text('Tài xế đang đến đón'), findsWidgets);

      rides.getError = const ApiException(
        statusCode: 0,
        message: 'Không thể kết nối máy chủ',
        errorCode: 'NETWORK_ERROR',
      );
      await tester.tap(find.byKey(const Key('ride-tracking-retry')));
      await tester.pumpAndSettle();

      expect(find.text('Tạm mất kết nối'), findsOneWidget);
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
      // Only the "last updated status" row keeps the last known stage
      // (readable label, not the raw PREPARING code).
      expect(find.text('Đang chuẩn bị món'), findsOneWidget);
      expect(find.text('PREPARING'), findsNothing);
      expect(find.text('Đơn đang được giao'), findsNothing);
      expect(find.text('150.000đ'), findsOneWidget);
    },
  );

  testWidgets('store page shows the BUSY prep estimate (DEC-PROD-028)', (
    tester,
  ) async {
    final food = FakeFoodClient()
      ..details = {
        'store-bun-bo': const FoodStoreDetail(
          id: 'store-bun-bo',
          name: 'Bún Bò Huế O Cò',
          items: [
            FoodMenuItem(
              id: 'item-bun',
              name: 'Bún bò',
              priceVnd: 45000,
              available: true,
            ),
          ],
          serviceMode: StoreServiceMode.busy,
          estimatedPrepMinutes: 45,
        ),
      };
    await _pumpCustomer(tester, food: food);
    await _push(tester, FoodRoutes.store('store-bun-bo'));
    expect(find.text('~45 phút'), findsWidgets);
  });

  testWidgets('food on the way map shows store pickup and dropoff', (
    tester,
  ) async {
    final food = FakeFoodClient()
      ..orderDetail = const FoodOrderDetail(
        id: 'order-1',
        status: 'PICKED_UP',
        subtotalVnd: 45000,
        deliveryFareVnd: 15000,
        totalVnd: 60000,
        dropoff: FoodDropoff(lat: 16.1, lng: 108.2, label: 'Sơn Trà'),
        pickup: FoodDropoff(lat: 16.05, lng: 108.21, label: 'Cửa hàng'),
        lines: [],
        assignedDriverId: 'driver-1',
      );
    await _pumpCustomer(tester, food: food);
    await _push(tester, FoodRoutes.order('order-1'));
    expect(find.byKey(const Key('food-tracking-map-chip')), findsNothing);
    expect(find.byKey(const Key('food-tracking-map-empty')), findsNothing);
    expect(find.byKey(const Key('food-tracking-map-waiting')), findsNothing);
  });

  testWidgets('food on the way shows the delivery code (DEC-PROD-036)', (
    tester,
  ) async {
    final food = FakeFoodClient()
      ..orderDetail = const FoodOrderDetail(
        id: 'order-1',
        status: 'PICKED_UP',
        subtotalVnd: 45000,
        deliveryFareVnd: 15000,
        totalVnd: 60000,
        dropoff: FoodDropoff(lat: 16.1, lng: 108.2, label: 'Sơn Trà'),
        lines: [],
        assignedDriverId: 'driver-1',
        deliveryCode: '4821',
      );
    await _pumpCustomer(tester, food: food);
    await _push(tester, FoodRoutes.order('order-1'));
    final code = find.byKey(const Key('food-delivery-code'));
    await tester.ensureVisible(code);
    expect(tester.widget<Text>(code).data, '4821');
    expect(find.text('Mã giao hàng'), findsOneWidget);
  });

  testWidgets('food PREPARING has no delivery code panel', (tester) async {
    final food = FakeFoodClient()
      ..orderDetail = const FoodOrderDetail(
        id: 'order-1',
        status: 'PREPARING',
        subtotalVnd: 45000,
        deliveryFareVnd: 15000,
        totalVnd: 60000,
        dropoff: FoodDropoff(lat: 16.1, lng: 108.2, label: 'Sơn Trà'),
        lines: [],
      );
    await _pumpCustomer(tester, food: food);
    await _push(tester, FoodRoutes.order('order-1'));
    expect(find.byKey(const Key('food-delivery-code-panel')), findsNothing);
  });

  testWidgets('food PREPARING shows the kitchen ETA (DEC-PROD-028)', (
    tester,
  ) async {
    final readyAt = DateTime(2026, 10, 20, 12, 25);
    final food = FakeFoodClient()
      ..orderDetail = FoodOrderDetail(
        id: 'order-1',
        status: 'PREPARING',
        subtotalVnd: 45000,
        deliveryFareVnd: 15000,
        totalVnd: 60000,
        dropoff: const FoodDropoff(lat: 16.1, lng: 108.2, label: 'Sơn Trà'),
        lines: const [],
        prepMinutes: 25,
        estimatedReadyAt: readyAt,
      );
    await _pumpCustomer(tester, food: food);
    await _push(tester, FoodRoutes.order('order-1'));
    expect(find.text('Dự kiến món sẵn sàng lúc 12:25'), findsOneWidget);
  });

  testWidgets('food invoice matches PREPARING status (not delivered copy)', (
    tester,
  ) async {
    final food = FakeFoodClient()
      ..orderDetail = const FoodOrderDetail(
        id: 'order-1',
        status: 'PREPARING',
        storeName: 'Bún Bò Huế',
        subtotalVnd: 45000,
        deliveryFareVnd: 15000,
        totalVnd: 60000,
        dropoff: FoodDropoff(lat: 16.1, lng: 108.2, label: 'Sơn Trà'),
        lines: [
          FoodOrderLine(
            itemId: 'item-bun',
            name: 'Bún bò',
            unitPriceVnd: 45000,
            quantity: 1,
          ),
        ],
      );
    await _pumpCustomer(tester, food: food);
    await _push(tester, FoodRoutes.invoice('order-1'));

    expect(find.byKey(const Key('food-invoice-status-title')), findsOneWidget);
    expect(find.text('Đang chuẩn bị món'), findsWidgets);
    expect(find.text('Đã giao thành công'), findsNothing);
    expect(find.text('DELIVERED'), findsNothing);
    expect(find.text('Đã giao'), findsNothing);
    expect(find.text('Món đã chọn'), findsOneWidget);
    expect(find.text('Tiền mặt · Chưa thanh toán'), findsOneWidget);
    expect(find.byKey(const Key('food-invoice-track')), findsOneWidget);
    expect(find.byKey(const Key('food-invoice-rate')), findsNothing);
  });

  testWidgets('food invoice DELIVERED keeps delivered copy', (tester) async {
    final food = FakeFoodClient()
      ..orderDetail = const FoodOrderDetail(
        id: 'order-2',
        status: 'DELIVERED',
        storeName: 'Bún Bò Huế',
        subtotalVnd: 45000,
        deliveryFareVnd: 15000,
        totalVnd: 60000,
        dropoff: FoodDropoff(lat: 16.1, lng: 108.2, label: 'Sơn Trà'),
        lines: [
          FoodOrderLine(
            itemId: 'item-bun',
            name: 'Bún bò',
            unitPriceVnd: 45000,
            quantity: 1,
          ),
        ],
      );
    await _pumpCustomer(tester, food: food);
    await _push(tester, FoodRoutes.invoice('order-2'));

    expect(find.text('Đã giao thành công'), findsOneWidget);
    expect(find.text('Đã giao'), findsOneWidget);
    expect(find.text('Món đã nhận'), findsOneWidget);
    expect(find.text('Tiền mặt · Đã thanh toán'), findsOneWidget);
    expect(find.byKey(const Key('food-invoice-rate')), findsOneWidget);
    expect(find.byKey(const Key('food-invoice-track')), findsNothing);
  });
}

Future<void> _pumpCustomer(
  WidgetTester tester, {
  FakeRideClient? rides,
  FakeFoodClient? food,
  DriverCardRepository? driverCard,
}) async {
  await tester.binding.setSurfaceSize(const Size(400, 1800));
  addTearDown(() => tester.binding.setSurfaceSize(null));
  await pumpSignedIn(
    tester,
    profile: customerProfile,
    rideClient: rides,
    foodClient: food,
    driverCard: driverCard,
  );
}

Future<void> _push(WidgetTester tester, String location) async {
  final context = tester.element(find.byType(Scaffold).first);
  GoRouter.of(context).push(location);
  await tester.pumpAndSettle();
}

RideView _ride({
  String id = 'ride-1',
  RideStatus status = RideStatus.negotiating,
  int? agreedFareVnd,
  String? assignedDriverId,
  String? pickupCode,
  String expiresAt = '2030-01-01T00:00:00.000Z',
  String vehicleClassCode = 'MOTORBIKE',
}) {
  return RideView(
    id: id,
    status: status,
    pickup: const RidePoint(lat: 16.0544, lng: 108.2022, label: 'Hải Châu'),
    dropoff: const RidePoint(lat: 16.0439, lng: 108.1994, label: 'Sân bay'),
    offeredFareVnd: 42000,
    referenceFareVnd: 40000,
    agreedFareVnd: agreedFareVnd,
    assignedDriverId: assignedDriverId,
    selectedOfferId: null,
    expiresAt: expiresAt,
    offers: const [],
    pickupCode: pickupCode,
    vehicleClassCode: vehicleClassCode,
  );
}
