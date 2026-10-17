import 'package:dealgo/features/food/data/datasources/dio_food_remote_datasource.dart';
import 'package:dealgo/features/food/domain/entities/food_models.dart';
import 'package:dealgo/core/network/api_exception.dart';
import 'package:dealgo/features/identity/domain/entities/user_profile.dart';
import 'package:dealgo/features/ride/data/models/ride_models.dart';
import 'package:dealgo/features/ride/domain/entities/ride_models.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/auth_test_harness.dart';
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

    expect(
      const SubmitRideOfferBody(amountVnd: 45000).toJson(),
      {'amountVnd': 45000},
    );
  });

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
    expect(find.text('Online'), findsOneWidget);
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

  testWidgets('posting an offer sends amountVnd', (tester) async {
    final ride = _openRide();
    final rides = FakeRideClient()
      ..openRides = [ride]
      ..onOffer = (request) => _offeredView(ride, request.amountVnd);
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
    expect(
      SubmitRideOfferBody(amountVnd: request.amountVnd).toJson(),
      {'amountVnd': 45000},
    );
    expect(find.text('Đã gửi báo giá'), findsOneWidget);
    expect(find.textContaining('COUNTER'), findsWidgets);
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
    expect(find.text('TAKEN / EXPIRED'), findsOneWidget);
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
    expect(find.text('Tạm hạn chế nhận chuyến'), findsWidgets);
    expect(find.text('Đã hết hạn'), findsWidgets);
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
  await tester.tap(navLabel('Công việc'));
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
}) {
  return ReadyFoodJob(
    id: id,
    storeId: 'store-1',
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
