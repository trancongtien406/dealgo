import 'package:dealgo/features/driver/presentation/utils/driver_routes.dart';
import 'package:dealgo/features/food/domain/entities/food_models.dart';
import 'package:dealgo/features/identity/domain/entities/user_profile.dart';
import 'package:dealgo/features/ride/data/datasources/ride_negotiation_clients.dart';
import 'package:dealgo/features/ride/domain/entities/ride_models.dart';
import 'package:dealgo/features/ride/presentation/utils/ride_routes.dart';
import 'package:dealgo/features/ride/domain/negotiation/ride_negotiation_client.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'support/auth_test_harness.dart';
import 'support/fake_food_client.dart';
import 'support/fake_identity_client.dart';
import 'support/fake_ride_client.dart';

RideView _negotiating({required int offerAmount, required String id}) =>
    RideView(
      id: id,
      status: RideStatus.negotiating,
      pickup: const RidePoint(lat: 16.0544, lng: 108.2022, label: '123 Lê Lợi'),
      dropoff: const RidePoint(lat: 16.0471, lng: 108.2062, label: 'Sân bay'),
      offeredFareVnd: 42000,
      referenceFareVnd: 40000,
      agreedFareVnd: null,
      assignedDriverId: null,
      selectedOfferId: null,
      expiresAt: '2030-01-01T00:00:00.000Z',
      offers: [
        RideOffer(
          id: 'offer-1',
          driverId: 'driver-1',
          amountVnd: offerAmount,
          kind: RideOfferKind.counter,
          status: RideOfferStatus.pending,
          expiresAt: '2030-01-01T00:00:00.000Z',
        ),
      ],
      vehicleClassCode: 'MOTORBIKE',
    );

const _driver = UserProfile(
  id: 'driver-1',
  phone: '+84933333333',
  email: null,
  phoneVerifiedAt: '2026-10-13T16:00:00.000Z',
  emailVerifiedAt: null,
  grants: [RoleGrant(role: 'DRIVER', status: 'ACTIVE')],
);

RideView _assigned(RideStatus status) => RideView(
  id: 'ride-7',
  status: status,
  pickup: const RidePoint(lat: 16.0544, lng: 108.2022, label: 'Hải Châu'),
  dropoff: const RidePoint(lat: 16.0439, lng: 108.1994, label: 'Sân bay'),
  offeredFareVnd: 42000,
  referenceFareVnd: 40000,
  agreedFareVnd: 42000,
  assignedDriverId: 'driver-1',
  selectedOfferId: 'offer-1',
  expiresAt: '2030-01-01T00:00:00.000Z',
  offers: const [],
  vehicleClassCode: 'MOTORBIKE',
);

FakeRideNegotiationClient _negotiation(WidgetTester tester) =>
    RepositoryProvider.of<RideNegotiationClient>(
      tester.element(find.byType(Navigator).first),
    ) as FakeRideNegotiationClient;

Future<void> _go(WidgetTester tester, String location) async {
  GoRouter.of(tester.element(find.byType(Navigator).first)).go(location);
  await tester.pumpAndSettle();
}

String _location(WidgetTester tester) =>
    GoRouter.of(tester.element(find.byType(Navigator).first))
        .routeInformationProvider
        .value
        .uri
        .path;

void main() {
  testWidgets('Driver cancels an accepted ride with a reason', (tester) async {
    await tester.binding.setSurfaceSize(const Size(400, 1800));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final rides = FakeRideClient()
      ..onGet = (_) => _assigned(RideStatus.driverEnRoute);
    await pumpSignedIn(
      tester,
      profile: _driver,
      rideClient: rides,
      foodClient: FakeFoodClient(),
    );
    await _go(tester, DriverRoutes.active('ride-7'));
    expect(find.byKey(const Key('driver-no-show')), findsNothing);
    await tester.tap(find.byKey(const Key('driver-cancel-ride')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('reason-VEHICLE_PROBLEM')));
    await tester.pumpAndSettle();
    expect(
      _negotiation(tester).calls,
      contains('driverCancel:ride-7:VEHICLE_PROBLEM'),
    );
    expect(_location(tester), DriverRoutes.services);
  });

  testWidgets('No-show is offered once arrived and confirmed', (tester) async {
    await tester.binding.setSurfaceSize(const Size(400, 1800));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final rides = FakeRideClient()
      ..onGet = (_) => _assigned(RideStatus.driverArrived);
    await pumpSignedIn(
      tester,
      profile: _driver,
      rideClient: rides,
      foodClient: FakeFoodClient(),
    );
    await _go(tester, DriverRoutes.active('ride-7'));
    await tester.tap(find.byKey(const Key('driver-no-show')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('driver-no-show-confirm')));
    await tester.pumpAndSettle();
    expect(_negotiation(tester).calls, contains('markNoShow:ride-7'));
    expect(_location(tester), DriverRoutes.services);
  });

  testWidgets('A too-early no-show keeps the driver on the ride', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(400, 1800));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final rides = FakeRideClient()
      ..onGet = (_) => _assigned(RideStatus.driverArrived);
    await pumpSignedIn(
      tester,
      profile: _driver,
      rideClient: rides,
      foodClient: FakeFoodClient(),
    );
    await _go(tester, DriverRoutes.active('ride-7'));
    _negotiation(tester).failWith = Exception('too early');
    await tester.tap(find.byKey(const Key('driver-no-show')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('driver-no-show-confirm')));
    await tester.pumpAndSettle();
    expect(_location(tester), DriverRoutes.active('ride-7'));
    expect(find.byKey(const Key('driver-no-show')), findsOneWidget);
  });

  testWidgets('Driver releases a claimed food order with a reason', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(400, 1800));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final food = FakeFoodClient()
      ..onGetOrder = (id) => FoodOrderDetail(
        id: id,
        status: 'ASSIGNED',
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
    await pumpSignedIn(
      tester,
      profile: _driver,
      rideClient: FakeRideClient(),
      foodClient: food,
    );
    await _go(tester, '/driver/food/order-9');
    await tester.tap(find.byKey(const Key('driver-food-release')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('reason-STORE_TOO_SLOW')));
    await tester.pumpAndSettle();
    expect(
      _negotiation(tester).calls,
      contains('releaseFoodOrder:order-9:STORE_TOO_SLOW'),
    );
    expect(_location(tester), '/driver/jobs');
  });

  testWidgets('Driver withdraws a pending offer', (tester) async {
    final ride = OpenRide(
      id: 'ride-open-1',
      status: 'NEGOTIATING',
      pickup: const RidePoint(lat: 16.0544, lng: 108.2022, label: '123 Lê Lợi'),
      dropoff: const RidePoint(lat: 16.0471, lng: 108.2062, label: 'Sân bay'),
      offeredFareVnd: 42000,
      referenceFareVnd: 40000,
      expiresAt: '2030-01-01T00:00:00.000Z',
      offerCount: 0,
    );
    final rides = FakeRideClient()
      ..openRides = [ride]
      ..onOffer = ((r) => _negotiating(offerAmount: r.amountVnd, id: ride.id))
      ..onGet = ((_) => _negotiating(offerAmount: 45000, id: ride.id));
    await pumpSignedIn(
      tester,
      profile: _driver,
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
    await tester.enterText(
      find.byKey(const Key('driver-offer-amount')),
      '45000',
    );
    await tester.tap(find.byKey(const Key('driver-submit-offer')));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.byKey(const Key('driver-withdraw-offer')));
    await tester.tap(find.byKey(const Key('driver-withdraw-offer')));
    await tester.pumpAndSettle();
    expect(_negotiation(tester).calls, contains('withdrawOffer:ride-open-1'));
    expect(_location(tester), '/driver/jobs');
  });

  testWidgets('Customer raises the fare and declines an offer', (tester) async {
    await tester.binding.setSurfaceSize(const Size(400, 1800));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final rides = FakeRideClient()
      ..onGet = (_) => _negotiating(offerAmount: 47000, id: 'ride-1');
    await pumpSignedIn(tester, profile: customerProfile, rideClient: rides);
    await _go(tester, RideRoutes.offers('ride-1'));
    await tester.tap(find.byKey(const Key('ride-decline-offer')));
    await tester.pumpAndSettle();
    expect(_negotiation(tester).calls, contains('declineOffer:ride-1:offer-1'));

    await tester.tap(find.byKey(const Key('ride-raise-fare')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('reason-raise-10000')));
    await tester.pumpAndSettle();
    expect(_negotiation(tester).calls, contains('raiseFare:ride-1:52000'));
  });
}
