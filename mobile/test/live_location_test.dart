import 'package:dealgo/features/driver/presentation/cubit/driver_duty_cubit.dart';
import 'package:dealgo/features/food/domain/entities/food_models.dart';
import 'package:dealgo/features/food/presentation/utils/food_routes.dart';
import 'package:dealgo/features/live_location/data/driver_location_remote_datasource.dart';
import 'package:dealgo/features/live_location/domain/driver_location.dart';
import 'package:dealgo/features/live_location/presentation/driver_location_reporter.dart';
import 'package:dealgo/features/presence/data/datasources/fake_presence_client.dart';
import 'package:dealgo/features/presence/data/repositories/presence_repository_impl.dart';
import 'package:dealgo/features/presence/domain/usecases/set_presence.dart';
import 'package:dealgo/features/ride/domain/entities/ride_models.dart';
import 'package:dealgo/features/ride/presentation/utils/ride_routes.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'support/auth_test_harness.dart';
import 'support/fake_food_client.dart';
import 'support/fake_identity_client.dart';
import 'support/fake_location.dart';
import 'support/fake_ride_client.dart';

void main() {
  test('decodes a live location and treats null/garbage as unknown', () {
    final live = decodeDriverLocation({
      'location': {
        'lat': 16.06,
        'lng': 108.21,
        'at': '2026-10-20T03:00:00.000Z',
      },
    });
    expect(live?.lat, 16.06);
    expect(live?.at, DateTime.utc(2026, 10, 20, 3));
    expect(decodeDriverLocation({'location': null}), isNull);
    expect(
      decodeDriverLocation({
        'location': {'lat': 'x'},
      }),
      isNull,
    );
  });

  group('DriverLocationReporter', () {
    test('reports a GPS fix while running and stops when stopped', () async {
      final repo = FakeDriverLocationRemoteDataSource();
      final reporter = DriverLocationReporter(
        repository: repo,
        location: FakeLocationService(lat: 16.07, lng: 108.22),
        accessToken: () => 'tok',
        interval: const Duration(hours: 1),
      );
      reporter.start();
      await reporter.tick();
      expect(repo.reports, isNotEmpty);
      expect(repo.reports.last, (lat: 16.07, lng: 108.22));
      reporter.stop();
      final before = repo.reports.length;
      await reporter.tick();
      expect(repo.reports.length, before);
    });

    test('sends nothing without permission or a session', () async {
      final repo = FakeDriverLocationRemoteDataSource();
      final denied = DriverLocationReporter(
        repository: repo,
        location: FakeLocationService.denied(),
        accessToken: () => 'tok',
        interval: const Duration(hours: 1),
      )..start();
      await denied.tick();
      denied.stop();
      final signedOut = DriverLocationReporter(
        repository: repo,
        location: FakeLocationService(),
        accessToken: () => null,
        interval: const Duration(hours: 1),
      )..start();
      await signedOut.tick();
      signedOut.stop();
      expect(repo.reports, isEmpty);
    });

    test('duty cubit starts reporting online and stops offline', () async {
      final reporter = DriverLocationReporter(
        repository: FakeDriverLocationRemoteDataSource(),
        location: FakeLocationService(),
        accessToken: () => 'tok',
        interval: const Duration(hours: 1),
      );
      final duty = DriverDutyCubit(
        setPresence: SetPresence(PresenceRepositoryImpl(FakePresenceClient())),
        accessToken: () => 'tok',
        locationReporter: reporter,
      );
      await duty.connect();
      expect(reporter.running, isTrue);
      await duty.disconnect();
      expect(reporter.running, isFalse);
      await duty.close();
    });
  });

  testWidgets('ride tracking shows the assigned driver live position', (
    tester,
  ) async {
    final rides = FakeRideClient()
      ..onGet = (_) => _ride(RideStatus.driverEnRoute);
    final live = FakeDriverLocationRemoteDataSource(
      location: DriverLiveLocation(
        lat: 16.05,
        lng: 108.2,
        at: DateTime(2026, 10, 20, 9, 41),
      ),
    );
    await _pump(tester, rides: rides, live: live);
    await _push(tester, RideRoutes.tracking('ride-1'));

    expect(live.reads.first, (job: TrackedJob.ride, id: 'ride-1'));
    expect(find.byKey(const Key('map-placeholder-driver')), findsOneWidget);
    expect(find.text('Vị trí tài xế lúc 09:41'), findsOneWidget);
  });

  testWidgets('a negotiating ride never asks for a driver position', (
    tester,
  ) async {
    final rides = FakeRideClient()
      ..onGet = (_) => _ride(RideStatus.negotiating, driver: null);
    final live = FakeDriverLocationRemoteDataSource();
    await _pump(tester, rides: rides, live: live);
    await _push(tester, RideRoutes.tracking('ride-1'));
    expect(live.reads, isEmpty);
    expect(find.byKey(const Key('tracking-driver-live')), findsNothing);
  });

  testWidgets(
    'PICKED_UP food order is on its way with the courier on the map',
    (tester) async {
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
        );
      final live = FakeDriverLocationRemoteDataSource(
        location: DriverLiveLocation(
          lat: 16.09,
          lng: 108.21,
          at: DateTime(2026, 10, 20, 12, 5),
        ),
      );
      await _pump(tester, food: food, live: live);
      await _push(tester, FoodRoutes.order('order-1'));

      expect(find.text('Đơn đang được giao'), findsWidgets);
      expect(find.text('Chưa rõ trạng thái đơn'), findsNothing);
      expect(live.reads.first, (job: TrackedJob.food, id: 'order-1'));
      expect(find.text('Vị trí tài xế lúc 12:05'), findsOneWidget);
    },
  );
}

Future<void> _pump(
  WidgetTester tester, {
  FakeRideClient? rides,
  FakeFoodClient? food,
  required DriverLocationRepository live,
}) async {
  await tester.binding.setSurfaceSize(const Size(400, 1800));
  addTearDown(() => tester.binding.setSurfaceSize(null));
  await pumpSignedIn(
    tester,
    profile: customerProfile,
    rideClient: rides,
    foodClient: food,
    driverLocation: live,
  );
}

Future<void> _push(WidgetTester tester, String location) async {
  final context = tester.element(find.byType(Scaffold).first);
  GoRouter.of(context).push(location);
  await tester.pumpAndSettle();
}

RideView _ride(RideStatus status, {String? driver = 'driver-1'}) {
  return RideView(
    id: 'ride-1',
    status: status,
    pickup: const RidePoint(lat: 16.0544, lng: 108.2022, label: 'Hải Châu'),
    dropoff: const RidePoint(lat: 16.0439, lng: 108.1994, label: 'Sân bay'),
    offeredFareVnd: 42000,
    referenceFareVnd: 40000,
    agreedFareVnd: 42000,
    assignedDriverId: driver,
    selectedOfferId: null,
    expiresAt: '2030-01-01T00:00:00.000Z',
    offers: const [],
  );
}
