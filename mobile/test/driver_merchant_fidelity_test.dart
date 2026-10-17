import 'package:dealgo/features/driver/presentation/utils/driver_routes.dart';
import 'package:dealgo/features/food/domain/entities/food_models.dart';
import 'package:dealgo/features/identity/domain/entities/user_profile.dart';
import 'package:dealgo/features/ride/domain/entities/ride_models.dart';
import 'package:dealgo/features/ride/domain/entities/ride_vehicle.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

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

const _merchantProfile = UserProfile(
  id: 'merchant-1',
  phone: '+84901110001',
  email: null,
  phoneVerifiedAt: '2026-10-13T16:00:00.000Z',
  emailVerifiedAt: null,
  grants: [RoleGrant(role: 'MERCHANT', status: 'ACTIVE')],
);

void main() {
  test('ridePickupCode is stable 4 digits for OTP UI', () {
    final code = ridePickupCode('DG-R26001');
    expect(code.length, 4);
    expect(int.tryParse(code), isNotNull);
    expect(ridePickupCode('DG-R26001'), code);
  });

  testWidgets('driver services page opens from home config', (tester) async {
    await pumpSignedIn(
      tester,
      profile: _driverProfile,
      rideClient: FakeRideClient(),
      foodClient: FakeFoodClient(),
    );
    await tester.tap(find.byKey(const Key('driver-go-online')));
    await tester.pumpAndSettle();
    expect(find.text('Online'), findsOneWidget);

    final router = GoRouter.of(tester.element(find.byKey(const Key('driver-go-offline'))));
    router.push(DriverRoutes.services);
    await tester.pumpAndSettle();

    expect(find.text('Chọn dịch vụ nhận việc'), findsOneWidget);
    expect(find.byKey(const Key('driver-services-save')), findsOneWidget);
    expect(find.byKey(const Key('driver-services-ride')), findsOneWidget);
    expect(find.byKey(const Key('driver-services-food')), findsOneWidget);
  });

  testWidgets('driver can open active ride demo after offer', (tester) async {
    final ride = const OpenRide(
      id: 'ride-open-1',
      status: 'NEGOTIATING',
      pickup: RidePoint(lat: 16.0544, lng: 108.2022, label: '123 Lê Lợi'),
      dropoff: RidePoint(lat: 16.0471, lng: 108.2062, label: 'Sân bay'),
      offeredFareVnd: 42000,
      referenceFareVnd: 40000,
      expiresAt: '2030-01-01T00:00:00.000Z',
      offerCount: 0,
    );
    final rides = FakeRideClient()
      ..openRides = [ride]
      ..onOffer = (request) => RideView(
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
            amountVnd: request.amountVnd,
            kind: RideOfferKind.accept,
            status: RideOfferStatus.pending,
            expiresAt: ride.expiresAt,
          ),
        ],
      );
    await pumpSignedIn(
      tester,
      profile: _driverProfile,
      rideClient: rides,
      foodClient: FakeFoodClient(),
    );
    await tester.tap(find.byKey(const Key('driver-go-online')));
    await tester.pumpAndSettle();
    await tester.tap(navLabel('Công việc'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('driver-ride-ride-open-1')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('driver-open-offer')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('driver-submit-offer')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('driver-open-active-ride')));
    await tester.pumpAndSettle();

    expect(find.text('Điều hướng đón khách'), findsOneWidget);
    expect(find.byKey(const Key('driver-active-arrived')), findsOneWidget);
  });

  testWidgets('merchant placed order shows reject + accept footer', (
    tester,
  ) async {
    final food = FakeFoodClient()
      ..queueOrders = [
        const MerchantQueueOrder(
          id: 'order-placed-1',
          storeId: 'store-1',
          status: 'PLACED',
          deliveryFareVnd: 25000,
          subtotalVnd: 125000,
          totalVnd: 150000,
          dropoff: FoodDropoff(
            lat: 16.1,
            lng: 108.22,
            label: '456 Trần Hưng Đạo',
          ),
          lineCount: 3,
          createdAt: '2026-10-14T02:20:00.000Z',
        ),
      ];
    await pumpSignedIn(tester, profile: _merchantProfile, foodClient: food);
    await tester.tap(navLabel('Đơn hàng'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('merchant-order-order-placed-1')));
    await tester.pumpAndSettle();

    expect(find.text('Từ chối'), findsOneWidget);
    expect(find.byKey(const Key('merchant-accept')), findsOneWidget);
    expect(find.text('Chi tiết đơn mới'), findsOneWidget);
  });
}
