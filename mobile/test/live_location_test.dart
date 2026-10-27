import 'package:dealgo/core/maps/map_lat_lng.dart';
import 'package:dealgo/core/maps/map_markers.dart';
import 'package:dealgo/core/realtime/fake_snapshot_realtime.dart';
import 'package:dealgo/core/realtime/snapshot_realtime.dart';
import 'package:dealgo/core/realtime/socket_snapshot_realtime.dart';
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
import 'package:geolocator/geolocator.dart';
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

  group('adaptive DriverLocationReporter (DEC-PROD-031 rev 2026-10-24)', () {
    late DateTime now;
    late _MovingLocation gps;
    late FakeDriverLocationRemoteDataSource repo;
    late DriverLocationReporter reporter;

    setUp(() {
      now = DateTime.utc(2026, 10, 24, 1);
      gps = _MovingLocation();
      repo = FakeDriverLocationRemoteDataSource();
      reporter = DriverLocationReporter(
        repository: repo,
        location: gps,
        accessToken: () => 'tok',
        clock: () => now,
      );
    });
    tearDown(() => reporter.stop());

    test(
      'idle default: distance filter drops small moves, keep-alive resends',
      () async {
        expect(reporter.policy.mode, 'IDLE');
        reporter.start();
        await pumpEventQueue(); // start() fires the first tick.
        expect(repo.reports, hasLength(1));

        // ~11 m north: below the 50 m idle filter.
        gps.lat += 0.0001;
        now = now.add(const Duration(seconds: 15));
        await reporter.tick();
        expect(repo.reports, hasLength(1));

        // ~111 m from the last sent fix: sent.
        gps.lat += 0.0009;
        now = now.add(const Duration(seconds: 15));
        await reporter.tick();
        expect(repo.reports, hasLength(2));

        // Parked: nothing until the 60 s idle keep-alive.
        now = now.add(const Duration(seconds: 45));
        await reporter.tick();
        expect(repo.reports, hasLength(2));
        now = now.add(const Duration(seconds: 15));
        await reporter.tick();
        expect(repo.reports, hasLength(3));
      },
    );

    test('adopts the server ON_TRIP policy from the POST reply', () async {
      repo.reply = decodeDriverLocationReport({
        'accepted': true,
        'policy': {
          'mode': 'ON_TRIP',
          'intervalMs': 5000,
          'minDistanceM': 10,
          'maxSilenceMs': 30000,
        },
      });
      reporter.start();
      await pumpEventQueue(); // start() fires the first tick.
      expect(reporter.policy.mode, 'ON_TRIP');
      expect(reporter.policy.interval, const Duration(seconds: 5));

      // ~11 m: now above the 10 m on-trip filter.
      gps.lat += 0.0001;
      now = now.add(const Duration(seconds: 5));
      await reporter.tick();
      expect(repo.reports, hasLength(2));
    });

    test(
      'sends heading/speed/accuracy/recordedAt; drops unknown values',
      () async {
        gps
          ..heading = 90
          ..speed = 7.5
          ..accuracy = 6;
        reporter.start();
        await pumpEventQueue(); // start() fires the first tick.
        final json = repo.fixes.single.toJson();
        expect(json['heading'], 90);
        expect(json['speedMps'], 7.5);
        expect(json['accuracyM'], 6);
        expect(json['recordedAt'], '2026-10-24T01:00:00.000Z');

        final parked = DriverLocationReporter.fixFromPosition(
          _position(16, 108, heading: 270, speed: 0, accuracy: 0),
        );
        expect(parked.heading, isNull, reason: 'course is noise when stopped');
        expect(parked.accuracyM, isNull);
        expect(parked.toJson().containsKey('heading'), isFalse);
      },
    );

    test('rejections and old server shapes keep the client policy', () {
      final rejected = decodeDriverLocationReport({
        'accepted': false,
        'reason': 'RATE_LIMITED',
      });
      expect(rejected.accepted, isFalse);
      expect(rejected.reason, 'RATE_LIMITED');
      expect(rejected.policy, isNull);
      expect(decodeDriverLocationReport(null).accepted, isTrue);
    });
  });

  group('marker motion helpers', () {
    test('heading uses device course only while moving', () {
      expect(
        driverMarkerHeading(
          deviceHeading: 400,
          speedMps: 5,
          movementBearing: 10,
        ),
        40,
      );
      expect(
        driverMarkerHeading(
          deviceHeading: 90,
          speedMps: 0.3,
          movementBearing: 10,
        ),
        10,
      );
      expect(driverMarkerHeading(), isNull);
      final east = bearingDegrees(
        const MapLatLng(lat: 16, lng: 108),
        const MapLatLng(lat: 16, lng: 108.01),
      )!;
      expect(east, closeTo(90, 0.5));
    });

    test('glide spans the gap between fixes, clamped', () {
      final t = DateTime.utc(2026);
      expect(driverGlideDuration(null, t), const Duration(milliseconds: 450));
      expect(
        driverGlideDuration(t, t.add(const Duration(seconds: 5))),
        const Duration(seconds: 5),
      );
      expect(
        driverGlideDuration(t, t.add(const Duration(minutes: 1))),
        const Duration(seconds: 6),
      );
    });

    test('parses heading and speed from driverLocation payloads', () {
      final hint = parseDriverLocationHint({
        'aggregateType': 'Ride',
        'aggregateId': 'r1',
        'lat': 16,
        'lng': 108,
        'at': '2026-10-24T00:00:00.000Z',
        'heading': 182.5,
        'speedMps': 9,
      });
      expect(hint?.heading, 182.5);
      expect(hint?.speedMps, 9.0);
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

  testWidgets('ride tracking is push-based: no poll, socket moves the driver', (
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
    final rt = FakeSnapshotRealtime();
    addTearDown(rt.dispose);
    await _pump(tester, rides: rides, live: live, realtime: rt);
    await _push(tester, RideRoutes.tracking('ride-1'));

    expect(rt.subscribed, contains('ride-location:ride-1'));
    final readsAfterOpen = live.reads.length;
    expect(readsAfterOpen, 1); // REST snapshot only.

    // A minute of wall time must not trigger any REST poll.
    await tester.pump(const Duration(seconds: 60));
    expect(live.reads.length, readsAfterOpen);

    rt.emitDriverLocation(
      DriverLocationHint(
        aggregateType: 'Ride',
        aggregateId: 'ride-1',
        lat: 16.051,
        lng: 108.201,
        at: DateTime(2026, 10, 20, 9, 45),
        heading: 45,
        speedMps: 8,
      ),
    );
    // Other rides' fixes are ignored.
    rt.emitDriverLocation(
      DriverLocationHint(
        aggregateType: 'Ride',
        aggregateId: 'ride-2',
        lat: 1,
        lng: 1,
        at: DateTime(2026, 10, 20, 9, 50),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Vị trí tài xế lúc 09:45'), findsOneWidget);
    expect(live.reads.length, readsAfterOpen);

    // Reconnect = one authoritative REST re-read.
    rt.emitReconnect();
    await tester.pumpAndSettle();
    expect(live.reads.length, readsAfterOpen + 1);
  });

  test('parses driverLocation socket payloads', () {
    final hint = parseDriverLocationHint({
      'aggregateType': 'FoodOrder',
      'aggregateId': 'o1',
      'lat': 16,
      'lng': 108.5,
      'at': '2026-10-24T00:00:00.000Z',
    });
    expect(hint?.aggregateId, 'o1');
    expect(hint?.lat, 16.0);
    expect(parseDriverLocationHint({'lat': 'x'}), isNull);
    expect(const FoodLocationRoom('o1').name, 'food-location:o1');
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

      expect(find.text('Tài xế đang giao tới bạn'), findsWidgets);
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
  SnapshotRealtime? realtime,
}) async {
  await tester.binding.setSurfaceSize(const Size(400, 1800));
  addTearDown(() => tester.binding.setSurfaceSize(null));
  await pumpSignedIn(
    tester,
    profile: customerProfile,
    rideClient: rides,
    foodClient: food,
    driverLocation: live,
    realtime: realtime,
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

Position _position(
  double lat,
  double lng, {
  double heading = -1,
  double speed = -1,
  double accuracy = 5,
}) => Position(
  latitude: lat,
  longitude: lng,
  timestamp: DateTime.utc(2026, 10, 24, 1),
  accuracy: accuracy,
  altitude: 0,
  altitudeAccuracy: 0,
  heading: heading,
  headingAccuracy: 0,
  speed: speed,
  speedAccuracy: 0,
);

/// GPS whose fix the test moves between ticks.
class _MovingLocation extends FakeLocationService {
  _MovingLocation() : super(lat: 16.0544, lng: 108.2022);

  double heading = -1;
  double speed = -1;
  double accuracy = 5;

  @override
  Future<Position?> currentPosition({
    LocationAccuracy accuracy = LocationAccuracy.high,
  }) async => _position(
    lat,
    lng,
    heading: heading,
    speed: speed,
    accuracy: this.accuracy,
  );
}
