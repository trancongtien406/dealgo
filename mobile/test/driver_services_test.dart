import 'package:dealgo/core/network/api_exception.dart';
import 'package:dealgo/features/driver/presentation/cubit/driver_services_cubit.dart';
import 'package:dealgo/features/driver/presentation/pages/driver_active_ride_page.dart';
import 'package:dealgo/features/driver/presentation/pages/driver_ride_page.dart';
import 'package:dealgo/features/identity/domain/entities/user_profile.dart';
import 'package:dealgo/features/presence/data/datasources/fake_presence_client.dart';
import 'package:dealgo/features/presence/data/repositories/presence_repository_impl.dart';
import 'package:dealgo/features/presence/domain/entities/driver_service_prefs.dart';
import 'package:dealgo/features/ride/domain/entities/ride_models.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'support/auth_test_harness.dart';
import 'support/fake_food_client.dart';
import 'support/fake_ride_client.dart';

import 'package:dealgo/core/realtime/fake_snapshot_realtime.dart';
import 'package:dealgo/core/realtime/snapshot_realtime.dart';

const _driverProfile = UserProfile(
  id: 'driver-1',
  phone: '+84933333333',
  email: null,
  phoneVerifiedAt: '2026-10-13T16:00:00.000Z',
  emailVerifiedAt: null,
  grants: [RoleGrant(role: 'DRIVER', status: 'ACTIVE')],
);

void main() {
  group('DriverServicesCubit', () {
    DriverServicesCubit build(
      FakePresenceClient presence, {
      bool online = true,
    }) => DriverServicesCubit(
      repository: PresenceRepositoryImpl(presence),
      accessToken: () => 'access-token',
      online: () => online,
    );

    test('load reads the server toggles', () async {
      final presence = FakePresenceClient(
        prefs: const DriverServicePrefs(rideEnabled: false, foodEnabled: true),
      );
      final cubit = build(presence);
      await cubit.load();
      expect(cubit.state.saved.rideEnabled, isFalse);
      expect(cubit.state.prefs, cubit.state.saved);
      expect(cubit.state.dirty, isFalse);
      await cubit.close();
    });

    test('save sends both toggles with the current duty state', () async {
      final presence = FakePresenceClient();
      final cubit = build(presence, online: false);
      await cubit.load();
      cubit.setFood(false);
      expect(cubit.state.dirty, isTrue);
      expect(await cubit.save(), isTrue);
      final call = presence.calls.single;
      expect(call.online, isFalse);
      expect(call.rideEnabled, isTrue);
      expect(call.foodEnabled, isFalse);
      expect(cubit.state.saved.foodEnabled, isFalse);
      expect(cubit.state.status, DriverServicesStatus.saved);
      await cubit.close();
    });

    test('a failed save keeps the last saved toggles', () async {
      final presence = FakePresenceClient()
        ..saveError = const ApiException(
          statusCode: 500,
          message: 'x',
          errorCode: 'X',
        );
      final cubit = build(presence);
      await cubit.load();
      cubit.setRide(false);
      expect(await cubit.save(), isFalse);
      expect(cubit.state.status, DriverServicesStatus.failed);
      expect(cubit.state.saved.rideEnabled, isTrue);
      await cubit.close();
    });
  });

  test('offer selection follows the ride status', () {
    expect(
      driverOfferSelectionFor(RideStatus.negotiating),
      DriverOfferSelection.waiting,
    );
    expect(
      driverOfferSelectionFor(RideStatus.assigned),
      DriverOfferSelection.selected,
    );
    expect(
      driverOfferSelectionFor(RideStatus.cancelled),
      DriverOfferSelection.lost,
    );
    expect(
      driverPhaseForStatus(RideStatus.driverArrived),
      DriverRidePhase.arrived,
    );
    expect(driverPhaseForStatus(RideStatus.inTrip), DriverRidePhase.onTrip);
    expect(driverPhaseForStatus(RideStatus.negotiating), isNull);
  });

  testWidgets('home switch saves the service toggle to the server', (
    tester,
  ) async {
    final presence = FakePresenceClient();
    await pumpSignedIn(
      tester,
      profile: _driverProfile,
      rideClient: FakeRideClient(),
      foodClient: FakeFoodClient(),
      presenceClient: presence,
    );
    await tester.tap(find.byKey(const Key('driver-go-online')));
    await tester.pumpAndSettle();
    expect(find.text('Hải Châu, Đà Nẵng'), findsNothing);

    final foodSwitch = find.byKey(const Key('driver-home-food-switch'));
    await tester.scrollUntilVisible(
      foodSwitch,
      120,
      scrollable: find.byType(Scrollable).last,
    );
    await tester.ensureVisible(foodSwitch);
    await tester.pumpAndSettle();
    await tester.tap(
      find.descendant(of: foodSwitch, matching: find.byType(Switch)),
    );
    await tester.pumpAndSettle();

    final last = presence.calls.last;
    expect(last.online, isTrue);
    expect(last.foodEnabled, isFalse);
    expect(last.rideEnabled, isTrue);
    expect(presence.prefs.foodEnabled, isFalse);
  });

  testWidgets(
    'navigation opens only after the customer picks this driver (no poll)',
    (tester) async {
      final ride = _openRide();
      var status = RideStatus.negotiating;
      final realtime = FakeSnapshotRealtime();
      final rides = FakeRideClient()
        ..openRides = [ride]
        ..onOffer = ((request) => _view(RideStatus.negotiating))
        ..onGet = ((_) => _view(status));
      await pumpSignedIn(
        tester,
        profile: _driverProfile,
        rideClient: rides,
        foodClient: FakeFoodClient(),
        realtime: realtime,
      );
      await tester.tap(find.byKey(const Key('driver-go-online')));
      await tester.pumpAndSettle();
      await tester.tap(navLabel('Việc nhận'));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('driver-ride-ride-open-1')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('driver-open-offer')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('driver-submit-offer')));
      await tester.pumpAndSettle();

      expect(find.text('Đúng giá khách · Chờ khách chọn'), findsOneWidget);
      final afterSubscribe = rides.getCalls.length;
      // DEC-PROD-031 rev: 60 s of silence → zero extra requests.
      await tester.pump(const Duration(seconds: 60));
      await tester.pumpAndSettle();
      expect(rides.getCalls.length, afterSubscribe);
      expect(find.byKey(const Key('driver-open-active-ride')), findsNothing);

      // Reconnect → exactly one authoritative refetch.
      realtime.emitReconnect();
      await tester.pumpAndSettle();
      expect(rides.getCalls.length, afterSubscribe + 1);

      status = RideStatus.assigned;
      realtime.emitHint(
        const SnapshotHint(
          aggregateType: 'Ride',
          aggregateId: 'ride-open-1',
          status: 'ASSIGNED',
          revision: '2',
          occurredAt: '2030-01-01T00:00:00.000Z',
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Khách đã chọn bạn'), findsOneWidget);
      expect(find.byKey(const Key('driver-open-active-ride')), findsOneWidget);
      expect(
        realtime.subscribed.where((r) => r.startsWith('ride-offers:')),
        isEmpty,
      );
    },
  );

  testWidgets(
    'DEC-PROD-025: the socket hint shows the choice without waiting for the poll',
    (tester) async {
      final ride = _openRide();
      var status = RideStatus.negotiating;
      final realtime = FakeSnapshotRealtime();
      final rides = FakeRideClient()
        ..openRides = [ride]
        ..onOffer = ((request) => _view(RideStatus.negotiating))
        ..onGet = ((_) => _view(status));
      await pumpSignedIn(
        tester,
        profile: _driverProfile,
        rideClient: rides,
        foodClient: FakeFoodClient(),
        realtime: realtime,
      );
      await tester.tap(find.byKey(const Key('driver-go-online')));
      await tester.pumpAndSettle();
      await tester.tap(navLabel('Việc nhận'));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('driver-ride-ride-open-1')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('driver-open-offer')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('driver-submit-offer')));
      await tester.pumpAndSettle();
      expect(realtime.subscribed, contains('ride:ride-open-1'));

      status = RideStatus.assigned;
      realtime.emitHint(
        const SnapshotHint(
          aggregateType: 'Ride',
          aggregateId: 'ride-open-1',
          status: 'ASSIGNED',
          revision: '1',
          occurredAt: '2030-01-01T00:00:00.000Z',
        ),
      );
      await tester.pump(const Duration(milliseconds: 50));
      await tester.pumpAndSettle();
      expect(find.text('Khách đã chọn bạn'), findsOneWidget);
      // One REST check after subscribe + one per hint; no poll.
      expect(rides.getCalls.where((id) => id == 'ride-open-1').length, 2);
    },
  );

  testWidgets('another driver chosen (404) shows not chosen', (tester) async {
    final ride = _openRide();
    final rides = FakeRideClient()
      ..openRides = [ride]
      ..onOffer = (request) => _view(RideStatus.negotiating);
    await pumpSignedIn(
      tester,
      profile: _driverProfile,
      rideClient: rides,
      foodClient: FakeFoodClient(),
    );
    await tester.tap(find.byKey(const Key('driver-go-online')));
    await tester.pumpAndSettle();
    await tester.tap(navLabel('Việc nhận'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('driver-ride-ride-open-1')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('driver-open-offer')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('driver-submit-offer')));
    await tester.pumpAndSettle();
    expect(find.text('Không được chọn'), findsOneWidget);
    expect(find.byKey(const Key('driver-offer-back-to-jobs')), findsOneWidget);
  });

  testWidgets('active ride without data loads the real ride, never a sample', (
    tester,
  ) async {
    final rides = FakeRideClient()
      ..onGet = (_) => _view(RideStatus.driverArrived, agreed: 47000);
    await pumpSignedIn(
      tester,
      profile: _driverProfile,
      rideClient: rides,
      foodClient: FakeFoodClient(),
    );
    GoRouter.of(tester.element(find.text('Tổng quan tài xế')))
        .push('/driver/rides/ride-open-1/active');
    await tester.pumpAndSettle();
    expect(rides.getCalls, contains('ride-open-1'));
    expect(find.textContaining('123 Lê Lợi'), findsWidgets);
    expect(find.textContaining('Nguyễn Văn Linh'), findsNothing);
    expect(find.byKey(const Key('driver-active-open-otp')), findsOneWidget);
  });

  testWidgets('DEC-PROD-024: the driver collects the fare minus the voucher', (
    tester,
  ) async {
    final rides = FakeRideClient()
      ..onGet = (_) =>
          _view(RideStatus.completed, agreed: 47000, discount: 10000);
    await pumpSignedIn(
      tester,
      profile: _driverProfile,
      rideClient: rides,
      foodClient: FakeFoodClient(),
    );
    GoRouter.of(tester.element(find.text('Tổng quan tài xế')))
        .push('/driver/rides/ride-open-1/active');
    await tester.pumpAndSettle();
    expect(find.text('Thu tiền mặt 37.000đ'), findsOneWidget);
    expect(find.textContaining('DealGo trả phần này cho bạn'), findsOneWidget);
    expect(find.text('47.000đ'), findsWidgets);
  });

  testWidgets('active ride that is not this assigned to this driver (404) says it is gone', (tester) async {
    final rides = FakeRideClient();
    await pumpSignedIn(
      tester,
      profile: _driverProfile,
      rideClient: rides,
      foodClient: FakeFoodClient(),
    );
    GoRouter.of(tester.element(find.text('Tổng quan tài xế')))
        .push('/driver/rides/ride-open-1/active');
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('driver-active-gone')), findsOneWidget);
  });
}

OpenRide _openRide() => const OpenRide(
  id: 'ride-open-1',
  status: 'NEGOTIATING',
  pickup: RidePoint(lat: 16.0544, lng: 108.2022, label: '123 Lê Lợi'),
  dropoff: RidePoint(lat: 16.0471, lng: 108.2062, label: 'Sân bay'),
  offeredFareVnd: 42000,
  referenceFareVnd: 40000,
  expiresAt: '2030-01-01T00:00:00.000Z',
  offerCount: 0,
);

RideView _view(RideStatus status, {int? agreed, int discount = 0}) => RideView(
  discountVnd: discount,
  voucherCode: discount > 0 ? 'RIDE10K' : null,
  id: 'ride-open-1',
  status: status,
  pickup: const RidePoint(lat: 16.0544, lng: 108.2022, label: '123 Lê Lợi'),
  dropoff: const RidePoint(lat: 16.0471, lng: 108.2062, label: 'Sân bay'),
  offeredFareVnd: 42000,
  referenceFareVnd: 40000,
  agreedFareVnd: agreed,
  assignedDriverId: status == RideStatus.negotiating ? null : 'driver-1',
  selectedOfferId: null,
  expiresAt: '2030-01-01T00:00:00.000Z',
  offers: const [],
);
