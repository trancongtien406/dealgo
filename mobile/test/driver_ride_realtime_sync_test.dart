import 'package:dealgo/core/realtime/fake_snapshot_realtime.dart';
import 'package:dealgo/core/realtime/snapshot_realtime.dart';
import 'package:dealgo/features/activity/domain/entities/history_models.dart';
import 'package:dealgo/features/driver/presentation/pages/driver_active_ride_page.dart';
import 'package:dealgo/features/driver/presentation/utils/driver_routes.dart';
import 'package:dealgo/features/identity/domain/entities/user_profile.dart';
import 'package:dealgo/features/ride/domain/entities/ride_models.dart';
import 'package:dealgo/features/shell/presentation/customer_activity_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'support/auth_test_harness.dart';
import 'support/fake_ride_client.dart';

const _driver = UserProfile(
  id: 'driver-1',
  phone: '+84933333333',
  email: null,
  phoneVerifiedAt: '2026-10-13T16:00:00.000Z',
  emailVerifiedAt: null,
  grants: [RoleGrant(role: 'DRIVER', status: 'ACTIVE')],
);

SnapshotHint _hint(String id, String status) => SnapshotHint(
  aggregateType: 'ride',
  aggregateId: id,
  status: status,
  revision: status,
  occurredAt: '2026-10-25T06:00:00.000Z',
);

/// Regression: the driver ride screen stayed on "arrived"
/// after the server moved the ride to IN_TRIP.
void main() {
  testWidgets('driver active ride follows server status via ride room', (
    tester,
  ) async {
    var status = RideStatus.driverArrived;
    final realtime = FakeSnapshotRealtime();
    final rides = FakeRideClient()..onGet = (_) => _ride(status);
    await tester.binding.setSurfaceSize(const Size(400, 1800));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await pumpSignedIn(
      tester,
      profile: _driver,
      rideClient: rides,
      realtime: realtime,
    );
    final context = tester.element(find.byType(Scaffold).first);
    GoRouter.of(context).push(DriverRoutes.active('ride-1'));
    await tester.pumpAndSettle();
    expect(realtime.subscribed, contains('ride:ride-1'));
    final state = tester.state<State<DriverActiveRidePage>>(
      find.byType(DriverActiveRidePage),
    );
    expect((state as dynamic).debugPhase, DriverRidePhase.arrived);

    final before = rides.getCalls.length;
    realtime.emitHint(_hint('other', 'IN_TRIP'));
    await tester.pumpAndSettle();
    expect(rides.getCalls.length, before, reason: 'other ride ignored');

    status = RideStatus.inTrip;
    realtime.emitHint(_hint('ride-1', 'IN_TRIP'));
    await tester.pumpAndSettle();
    expect(rides.getCalls.length, before + 1);
    expect((state as dynamic).debugPhase, DriverRidePhase.onTrip);

    status = RideStatus.cancelled;
    realtime.emitHint(_hint('ride-1', 'CANCELLED'));
    await tester.pumpAndSettle();
    expect(find.byType(DriverActiveRidePage), findsNothing);
    expect(realtime.subscribed, isNot(contains('ride:ride-1')));
  });

  testWidgets('socket rideUnassigned leaves the trip page with the reason', (
    tester,
  ) async {
    final realtime = FakeSnapshotRealtime();
    final rides = FakeRideClient()..onGet = (_) => _ride(RideStatus.assigned);
    await tester.binding.setSurfaceSize(const Size(400, 1800));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await pumpSignedIn(
      tester,
      profile: _driver,
      rideClient: rides,
      realtime: realtime,
    );
    final context = tester.element(find.byType(Scaffold).first);
    GoRouter.of(context).push(DriverRoutes.active('ride-1'));
    await tester.pumpAndSettle();
    expect(find.byType(DriverActiveRidePage), findsOneWidget);

    // Another ride: nothing happens to this page.
    realtime.emitRideUnassigned(
      const RideUnassignedHint(rideId: 'other', reasonCode: 'ASSIGNED_TIMEOUT'),
    );
    await tester.pumpAndSettle();
    expect(find.byType(DriverActiveRidePage), findsOneWidget);
    ScaffoldMessenger.of(tester.element(find.byType(DriverActiveRidePage)))
        .hideCurrentSnackBar();
    await tester.pumpAndSettle();

    rides.onGet = (_) => _ride(RideStatus.negotiating, driver: null);
    realtime.emitRideUnassigned(
      const RideUnassignedHint(
        rideId: 'ride-1',
        reasonCode: 'ASSIGNED_TIMEOUT',
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byType(DriverActiveRidePage), findsNothing);
    expect(
      find.textContaining('Chuyến đã chuyển cho tài xế khác'),
      findsOneWidget,
    );
    expect(
      find.textContaining('Bạn chưa bắt đầu đi đón khách đúng hạn.'),
      findsOneWidget,
    );
  });

  testWidgets('ride back to NEGOTIATING (no driver) closes the trip page', (
    tester,
  ) async {
    var status = RideStatus.driverEnRoute;
    String? driver = 'driver-1';
    final realtime = FakeSnapshotRealtime();
    final rides = FakeRideClient()
      ..onGet = (_) => _ride(status, driver: driver);
    await tester.binding.setSurfaceSize(const Size(400, 1800));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await pumpSignedIn(
      tester,
      profile: _driver,
      rideClient: rides,
      realtime: realtime,
    );
    final context = tester.element(find.byType(Scaffold).first);
    GoRouter.of(context).push(DriverRoutes.active('ride-1'));
    await tester.pumpAndSettle();
    expect(find.byType(DriverActiveRidePage), findsOneWidget);

    status = RideStatus.negotiating;
    driver = null;
    realtime.emitHint(_hint('ride-1', 'NEGOTIATING'));
    await tester.pumpAndSettle();
    expect(find.byType(DriverActiveRidePage), findsNothing);
    expect(realtime.subscribed, isNot(contains('ride:ride-1')));
  });

  test('parseRideUnassignedHint', () {
    final hint = parseRideUnassignedHint({
      'rideId': 'ride-1',
      'reasonCode': 'EN_ROUTE_TIMEOUT',
      'actor': 'SYSTEM',
      'fromStatus': 'DRIVER_EN_ROUTE',
    });
    expect(hint?.rideId, 'ride-1');
    expect(hint?.reasonCode, 'EN_ROUTE_TIMEOUT');
    expect(hint?.fromStatus, 'DRIVER_EN_ROUTE');
    expect(parseRideUnassignedHint({'reasonCode': 'X'}), isNull);
    expect(parseRideUnassignedHint('nope'), isNull);
  });

  test('activity list watches only unfinished rows', () {
    const items = [
      HistoryItem(
        id: 'r1',
        kind: HistoryKind.ride,
        title: '',
        meta: '',
        status: 'IN_TRIP',
        amountVnd: null,
      ),
      HistoryItem(
        id: 'r2',
        kind: HistoryKind.ride,
        title: '',
        meta: '',
        status: 'COMPLETED',
        amountVnd: null,
      ),
      HistoryItem(
        id: 'f1',
        kind: HistoryKind.food,
        title: '',
        meta: '',
        status: 'PREPARING',
        amountVnd: null,
      ),
    ];
    final rooms = activeHistoryRooms(items).map((r) => r.name).toList();
    expect(rooms, ['ride:r1', 'food:f1']);
    expect(historyStatusIsFinal('DELIVERED'), isTrue);
  });
}

RideView _ride(RideStatus status, {String? driver = 'driver-1'}) => RideView(
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
  vehicleClassCode: 'MOTORBIKE',
);
