import 'package:dealgo/features/food/data/datasources/dio_food_remote_datasource.dart';
import 'package:dealgo/features/food/domain/entities/food_models.dart';
import 'package:dealgo/core/network/api_exception.dart';
import 'package:dealgo/features/food/domain/params/food_delivery_action.dart';
import 'package:dealgo/features/identity/domain/entities/user_profile.dart';
import 'package:dealgo/features/ride/data/models/ride_models.dart';
import 'package:dealgo/features/ride/domain/entities/ride_models.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:dealgo/core/navigation/external_navigator.dart';

import 'support/auth_test_harness.dart';
import 'support/fake_external_navigator.dart';
import 'support/fake_food_client.dart';
import 'support/fake_ride_client.dart';

const _driverProfile = UserProfile(
  id: 'driver-1',
  phone: '+84933333333',
  email: null,
  phoneVerifiedAt: '2026-10-13T16:00:00.000Z',
  emailVerifiedAt: null,
  grants: [RoleGrant(role: 'DRIVER', status: 'ACTIVE')],
);

void main() {
  test('open ride and ready food lists read the success envelope', () {
    final rides = OpenRideModel.listFromResponseBody({
      'success': true,
      'data': [
        {
          'id': 'ride-1',
          'status': 'NEGOTIATING',
          'pickup': {'lat': 16.05, 'lng': 108.2, 'label': 'Đón'},
          'dropoff': {'lat': 16.04, 'lng': 108.21, 'label': 'Đến'},
          'offeredFareVnd': 42000,
          'referenceFareVnd': 40000,
          'expiresAt': '2030-01-01T00:00:00.000Z',
          'offerCount': 2,
        },
      ],
    });
    expect(rides.single.offerCount, 2);
    expect(rides.single.offeredFareVnd, 42000);

    final jobs = decodeReadyFoodJobs({
      'success': true,
      'data': [
        {
          'id': 'food-1',
          'storeId': 'store-1',
          'deliveryFareVnd': 25000,
          'subtotalVnd': 150000,
          'totalVnd': 175000,
          'dropoff': {'lat': 16.1, 'lng': 108.2, 'label': 'Khách'},
          'lineCount': 2,
        },
      ],
    });
    expect(jobs.single.lineCount, 2);
    expect(jobs.single.deliveryFareVnd, 25000);
    expect(jobs.single.pickup, isNull);

    // DEC-PROD-034: order pickup snapshot; legacy `store` coords still read.
    final withPickup = decodeReadyFoodJobs({
      'success': true,
      'data': [
        {
          'id': 'food-2',
          'storeId': 'store-1',
          'storeName': 'Bún chả cá',
          'storeAddress': 'Địa chỉ hiện tại',
          'deliveryFareVnd': 25000,
          'subtotalVnd': 150000,
          'totalVnd': 175000,
          'dropoff': {'lat': 16.1, 'lng': 108.2, 'label': 'Khách'},
          'pickup': {'lat': 16.06, 'lng': 108.22, 'label': '12 Bạch Đằng'},
          'store': {'lat': 16.06, 'lng': 108.22},
          'lineCount': 1,
        },
        {
          'id': 'food-3',
          'storeId': 'store-1',
          'storeName': 'Cơm gà',
          'deliveryFareVnd': 25000,
          'subtotalVnd': 150000,
          'totalVnd': 175000,
          'dropoff': {'lat': 16.1, 'lng': 108.2, 'label': 'Khách'},
          'store': {'lat': 16.07, 'lng': 108.23},
          'lineCount': 1,
        },
      ],
    });
    expect(withPickup[0].pickup?.label, '12 Bạch Đằng');
    expect(withPickup[0].pickup?.lat, 16.06);
    expect(withPickup[1].pickup?.lng, 108.23);
    expect(withPickup[1].pickup?.label, 'Cơm gà');

    expect(const SubmitRideOfferBody(amountVnd: 45000).toJson(), {
      'amountVnd': 45000,
    });
  });

  for (final (status, title) in [
    ('ASSIGNED', 'Đang tới quán'),
    ('PICKED_UP', 'Giao tới khách'),
  ]) {
    testWidgets('relaunch on /driver/food/:id loads a $status order by id', (
      tester,
    ) async {
      final food = FakeFoodClient()
        ..onGetOrder = (id) => FoodOrderDetail(
          id: id,
          status: status,
          subtotalVnd: 90000,
          deliveryFareVnd: 15000,
          totalVnd: 105000,
          dropoff: const FoodDropoff(
            lat: 16.1,
            lng: 108.2,
            label: '456 Trần Hưng Đạo',
          ),
          lines: const [],
          assignedDriverId: 'driver-1',
          storeName: 'Bún chả cá',
          pickup: const FoodDropoff(
            lat: 16.06,
            lng: 108.22,
            label: '12 Bạch Đằng',
          ),
        );
      await _openDriver(tester, rides: FakeRideClient(), food: food);
      expect(find.byKey(const Key('driver-go-online')), findsOneWidget);
      GoRouter.of(tester.element(find.byType(Scaffold).first))
          .go('/driver/food/order-9');
      await tester.pumpAndSettle();
      expect(find.text(title), findsWidgets);
      expect(find.textContaining('Không tìm thấy yêu cầu'), findsNothing);
      // Back on duty (presence + location reporter).
      GoRouter.of(tester.element(find.byType(Scaffold).first)).go('/driver');
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('driver-go-online')), findsNothing);
    });
  }

  testWidgets('offline toggle does not request jobs', (tester) async {
    final rides = FakeRideClient();
    final food = FakeFoodClient();
    await _openDriver(tester, rides: rides, food: food);

    expect(find.text('Bạn đang ngoại tuyến'), findsOneWidget);
    expect(rides.openCalls, isEmpty);
    expect(food.readyCalls, isEmpty);

    await tester.tap(find.byKey(const Key('driver-go-online')));
    await tester.pumpAndSettle();
    expect(find.text('Tổng quan tài xế'), findsOneWidget);
    expect(find.text('Trực tuyến'), findsOneWidget);
    expect(rides.openCalls, isEmpty);
    expect(food.readyCalls, isEmpty);

    await tester.tap(find.byKey(const Key('driver-go-offline')));
    await tester.pumpAndSettle();
    expect(find.text('Bạn đang ngoại tuyến'), findsOneWidget);
    expect(rides.openCalls, isEmpty);
    expect(food.readyCalls, isEmpty);
  });

  testWidgets('online feed shows a ride from the fake client', (tester) async {
    final rides = FakeRideClient()..openRides = [_openRide()];
    final food = FakeFoodClient();
    await _openDriver(tester, rides: rides, food: food);
    await _connectAndOpenJobs(tester);

    expect(rides.openCalls, ['access-token']);
    expect(food.readyCalls, ['access-token']);
    expect(find.text('123 Lê Lợi'), findsOneWidget);
    expect(find.text('42.000đ'), findsWidgets);
    expect(find.textContaining('Xe máy'), findsWidgets);
  });

  testWidgets('ride ref never wraps mid-word beside the chips', (tester) async {
    // Sim (402pt): "Chuyến #1573" broke mid-word beside the two chips. The
    // ref is now a single unwrapped line that scales down to fit. (Test fonts
    // are much wider than device fonts, so assert the layout contract.)
    final rides = FakeRideClient()..openRides = [_openRide()];
    await _openDriver(tester, rides: rides, food: FakeFoodClient());
    await _connectAndOpenJobs(tester);

    final ref = find.byKey(const Key('driver-ride-ref-ride-open-1'));
    final text = tester.widget<Text>(ref);
    expect(text.maxLines, 1);
    expect(text.softWrap, isFalse);
    final fit = tester.widget<FittedBox>(
      find.ancestor(of: ref, matching: find.byType(FittedBox)).first,
    );
    expect(fit.fit, BoxFit.scaleDown);
    expect(
      tester.renderObject<RenderParagraph>(ref).didExceedMaxLines,
      isFalse,
    );
  });

  testWidgets('one-tap accept sends the customer price', (tester) async {
    final ride = _openRide();
    final rides = FakeRideClient()
      ..openRides = [ride]
      ..onOffer = ((request) => _offeredView(ride, request.amountVnd))
      ..onGet = ((_) => _offeredView(ride, ride.offeredFareVnd));
    final food = FakeFoodClient();
    await _openDriver(tester, rides: rides, food: food);
    await _connectAndOpenJobs(tester);

    await tester.tap(find.byKey(const Key('driver-ride-ride-open-1')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('driver-quick-accept')));
    await tester.pumpAndSettle();

    expect(rides.offerCalls, hasLength(1));
    expect(rides.offerCalls.single.amountVnd, ride.offeredFareVnd);
  });

  testWidgets('posting an offer sends amountVnd', (tester) async {
    final ride = _openRide();
    final rides = FakeRideClient()
      ..openRides = [ride]
      ..onOffer = ((request) => _offeredView(ride, request.amountVnd))
      // Snapshot GET right after the socket subscribe (DEC-PROD-031 rev).
      ..onGet = ((_) => _offeredView(ride, 45000));
    final food = FakeFoodClient();
    await _openDriver(tester, rides: rides, food: food);
    await _connectAndOpenJobs(tester);

    await tester.tap(find.byKey(const Key('driver-ride-ride-open-1')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('driver-open-offer')));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const Key('driver-offer-amount')),
      '45000',
    );
    await tester.tap(find.byKey(const Key('driver-submit-offer')));
    await tester.pumpAndSettle();

    expect(rides.offerCalls, hasLength(1));
    final request = rides.offerCalls.single;
    expect(request.rideId, 'ride-open-1');
    expect(request.accessToken, 'access-token');
    expect(request.amountVnd, 45000);
    expect(SubmitRideOfferBody(amountVnd: request.amountVnd).toJson(), {
      'amountVnd': 45000,
    });
    expect(find.text('Đã gửi báo giá'), findsOneWidget);
    expect(find.text('Giá của bạn · Chờ khách chọn'), findsOneWidget);
    // No navigation before the customer actually picks this driver.
    expect(find.byKey(const Key('driver-open-active-ride')), findsNothing);
  });

  testWidgets('food job shows the store pickup point and map (DEC-PROD-034)', (
    tester,
  ) async {
    final food = FakeFoodClient()
      ..readyOrders = [
        _readyJob(
          pickup: const FoodDropoff(
            lat: 16.06,
            lng: 108.22,
            label: '12 Bạch Đằng',
          ),
        ),
        _readyJob(id: 'food-job-2'),
      ];
    await _openDriver(tester, rides: FakeRideClient(), food: food);
    await _connectAndOpenJobs(tester);

    await tester.tap(find.byKey(const Key('driver-food-food-job-1')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('driver-food-map')), findsOneWidget);
    expect(find.byKey(const Key('driver-food-no-store-point')), findsNothing);
    expect(find.text('Bún chả cá · 12 Bạch Đằng'), findsOneWidget);
  });

  testWidgets(
    'claimed food job offers Google Maps / Waze and reports a failed hand-off',
    (tester) async {
      final food = FakeFoodClient()
        ..readyOrders = [
          _readyJob(
            pickup: const FoodDropoff(
              lat: 16.06,
              lng: 108.22,
              label: '12 Bạch Đằng',
            ),
          ),
        ]
        ..claimed = const ClaimedFoodDelivery(
          id: 'food-job-1',
          status: 'ASSIGNED',
        );
      final nav = FakeExternalNavigator(result: false);
      await pumpSignedIn(
        tester,
        profile: _driverProfile,
        rideClient: FakeRideClient(),
        foodClient: food,
        externalNavigator: nav,
      );
      await _connectAndOpenJobs(tester);
      await tester.tap(find.byKey(const Key('driver-food-food-job-1')));
      await tester.pumpAndSettle();
      // Not before the claim.
      expect(find.byKey(const Key('driver-nav-buttons')), findsNothing);
      await tester.tap(find.byKey(const Key('driver-claim-job')));
      await tester.pumpAndSettle();

      final navOpen = find.byKey(const Key('driver-nav-open'));
      await tester.ensureVisible(navOpen);
      await tester.pumpAndSettle();
      await tester.tap(navOpen);
      await tester.pumpAndSettle();
      expect(find.text('Đến quán lấy món'), findsOneWidget);
      final google = find.byKey(const Key('driver-nav-google'));
      await tester.tap(google);
      await tester.pumpAndSettle();
      expect(nav.calls, [(NavigationApp.googleMaps, 16.06, 108.22)]);
      expect(
        find.text(
          'Không mở được ứng dụng chỉ đường. Kiểm tra Google Maps hoặc Waze trên máy.',
        ),
        findsOneWidget,
      );
    },
  );

  testWidgets('pickup and delivery ask for the server codes (DEC-PROD-036)', (
    tester,
  ) async {
    final food = FakeFoodClient()
      ..readyOrders = [
        _readyJob(
          pickup: const FoodDropoff(
            lat: 16.06,
            lng: 108.22,
            label: '12 Bạch Đằng',
          ),
        ),
      ]
      ..claimed = const ClaimedFoodDelivery(
        id: 'food-job-1',
        status: 'ASSIGNED',
      )
      ..expectedHandoverCode = '2891'
      ..expectedDeliveryCode = '4821';
    await pumpSignedIn(
      tester,
      profile: _driverProfile,
      rideClient: FakeRideClient(),
      foodClient: food,
      externalNavigator: FakeExternalNavigator(),
    );
    await _connectAndOpenJobs(tester);
    await tester.tap(find.byKey(const Key('driver-food-food-job-1')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('driver-claim-job')));
    await tester.pumpAndSettle();

    Future<void> enter(String code) async {
      expect(find.byKey(const Key('driver-food-code-sheet')), findsOneWidget);
      await tester.enterText(
        find.byKey(const Key('driver-food-code-input')),
        code,
      );
      await tester.pump();
      await tester.tap(find.byKey(const Key('driver-food-code-submit')));
      await tester.pumpAndSettle();
    }

    // Handover: the store's code is asked for, a wrong one is flagged.
    await tester.tap(find.byKey(const Key('driver-food-pickup')));
    await tester.pumpAndSettle();
    expect(find.text('Mã bàn giao'), findsWidgets);
    await enter('1111');
    expect(find.text('Mã chưa đúng, kiểm tra lại.'), findsOneWidget);
    await enter('2891');
    expect(find.byKey(const Key('driver-food-code-sheet')), findsNothing);

    await tester.tap(find.byKey(const Key('driver-food-complete')));
    await tester.pumpAndSettle();
    expect(find.text('Mã giao hàng'), findsWidgets);
    await enter('4821');
    expect(find.byKey(const Key('driver-food-home')), findsOneWidget);
    expect(food.submittedCodes, [
      (action: FoodDeliveryAction.pickup, code: null),
      (action: FoodDeliveryAction.pickup, code: '1111'),
      (action: FoodDeliveryAction.pickup, code: '2891'),
      (action: FoodDeliveryAction.deliver, code: null),
      (action: FoodDeliveryAction.deliver, code: '4821'),
    ]);
  });

  testWidgets('a locked delivery code shows the support message', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(400, 1800));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final food = FakeFoodClient()
      ..readyOrders = [_readyJob()]
      ..claimed = const ClaimedFoodDelivery(
        id: 'food-job-1',
        status: 'ASSIGNED',
      );
    await pumpSignedIn(
      tester,
      profile: _driverProfile,
      rideClient: FakeRideClient(),
      foodClient: food,
      externalNavigator: FakeExternalNavigator(),
    );
    await _connectAndOpenJobs(tester);
    await tester.tap(find.byKey(const Key('driver-food-food-job-1')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('driver-claim-job')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('driver-food-pickup')));
    await tester.pumpAndSettle();
    food.advanceError = const ApiException(
      statusCode: 423,
      message: 'locked',
      errorCode: 'FOOD_DELIVERY_CODE_LOCKED',
    );
    await tester.tap(find.byKey(const Key('driver-food-complete')));
    await tester.pumpAndSettle();
    expect(
      find.text('Nhập sai quá số lần cho phép. Liên hệ hỗ trợ để xử lý đơn.'),
      findsOneWidget,
    );
    expect(find.byKey(const Key('driver-food-code-sheet')), findsNothing);
  });

  testWidgets('food job without store coordinates says to follow the address', (
    tester,
  ) async {
    final food = FakeFoodClient()..readyOrders = [_readyJob(id: 'food-job-2')];
    await _openDriver(tester, rides: FakeRideClient(), food: food);
    await _connectAndOpenJobs(tester);
    await tester.tap(find.byKey(const Key('driver-food-food-job-2')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('driver-food-map')), findsOneWidget);
    expect(find.byKey(const Key('driver-food-no-store-point')), findsOneWidget);
  });

  testWidgets('409 on food claim shows the job-taken message and not success', (
    tester,
  ) async {
    final rides = FakeRideClient();
    final food = FakeFoodClient()
      ..readyOrders = [_readyJob()]
      ..claimError = const ApiException(
        statusCode: 409,
        message: 'The order is already assigned',
        errorCode: 'FOOD_ALREADY_ASSIGNED',
      );
    await _openDriver(tester, rides: rides, food: food);
    await _connectAndOpenJobs(tester);

    await tester.tap(find.byKey(const Key('driver-food-food-job-1')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('driver-claim-job')));
    await tester.pumpAndSettle();

    expect(food.claimCalls, ['food-job-1']);
    expect(find.text('Yêu cầu đã được nhận'), findsOneWidget);
    expect(find.text('Yêu cầu không còn khả dụng'), findsOneWidget);
    expect(find.text('Giao đồ ăn'), findsWidgets);
    expect(find.text('Nhận việc'), findsNothing);
    expect(find.textContaining('thành công'), findsNothing);
    expect(find.text('Đã gửi yêu cầu nhận việc'), findsNothing);
  });

  testWidgets('403 ROLE_NOT_ACTIVE shows the ineligible state', (tester) async {
    final rides = FakeRideClient()
      ..openRides = [_openRide()]
      ..openError = const ApiException(
        statusCode: 403,
        message: 'An active driver role is required',
        errorCode: 'ROLE_NOT_ACTIVE',
      );
    final food = FakeFoodClient()
      ..readyOrders = [
        _readyJob(
          id: 'hidden-food',
          dropoff: 'Không được hiện như danh sách trống',
        ),
      ];
    await _openDriver(tester, rides: rides, food: food);
    await _connectAndOpenJobs(tester);

    expect(rides.openCalls, isNotEmpty);
    expect(food.readyCalls, isNotEmpty);
    expect(find.text('Chưa thể nhận việc'), findsOneWidget);
    expect(find.byKey(const Key('driver-open-application')), findsOneWidget);
    expect(find.text('Chưa có yêu cầu đang mở'), findsNothing);
    expect(find.text('123 Lê Lợi'), findsNothing);
    expect(find.text('Không được hiện như danh sách trống'), findsNothing);
  });
}

Future<void> _openDriver(
  WidgetTester tester, {
  required FakeRideClient rides,
  required FakeFoodClient food,
}) {
  return pumpSignedIn(
    tester,
    profile: _driverProfile,
    rideClient: rides,
    foodClient: food,
  );
}

Future<void> _connectAndOpenJobs(WidgetTester tester) async {
  await tester.tap(find.byKey(const Key('driver-go-online')));
  await tester.pumpAndSettle();
  await tester.tap(navLabel('Việc nhận'));
  await tester.pumpAndSettle();
}

OpenRide _openRide() {
  return const OpenRide(
    id: 'ride-open-1',
    status: 'NEGOTIATING',
    pickup: RidePoint(lat: 16.0544, lng: 108.2022, label: '123 Lê Lợi'),
    dropoff: RidePoint(lat: 16.0471, lng: 108.2062, label: 'Sân bay'),
    offeredFareVnd: 42000,
    referenceFareVnd: 40000,
    expiresAt: '2030-01-01T00:00:00.000Z',
    offerCount: 0,
  );
}

ReadyFoodJob _readyJob({
  String id = 'food-job-1',
  String dropoff = '456 Trần Hưng Đạo',
  FoodDropoff? pickup,
}) {
  return ReadyFoodJob(
    id: id,
    storeId: 'store-1',
    storeName: 'Bún chả cá',
    pickup: pickup,
    deliveryFareVnd: 25000,
    subtotalVnd: 150000,
    totalVnd: 175000,
    dropoff: FoodDropoff(lat: 16.1, lng: 108.22, label: dropoff),
    lineCount: 2,
  );
}

RideView _offeredView(OpenRide ride, int amountVnd) {
  return RideView(
    id: ride.id,
    status: RideStatus.negotiating,
    pickup: ride.pickup,
    dropoff: ride.dropoff,
    offeredFareVnd: ride.offeredFareVnd,
    referenceFareVnd: ride.referenceFareVnd,
    agreedFareVnd: null,
    assignedDriverId: null,
    selectedOfferId: null,
    expiresAt: ride.expiresAt,
    offers: [
      RideOffer(
        id: 'offer-1',
        driverId: 'driver-1',
        amountVnd: amountVnd,
        kind: RideOfferKind.counter,
        status: RideOfferStatus.pending,
        expiresAt: ride.expiresAt,
      ),
    ],
  );
}
