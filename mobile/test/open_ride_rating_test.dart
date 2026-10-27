import 'package:dealgo/features/identity/domain/entities/user_profile.dart';
import 'package:dealgo/features/ride/domain/entities/ride_models.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/auth_test_harness.dart';
import 'support/fake_food_client.dart';
import 'support/fake_ride_client.dart';

const _driver = UserProfile(
  id: 'driver-1',
  phone: '+84933333333',
  email: null,
  phoneVerifiedAt: '2026-10-13T16:00:00.000Z',
  emailVerifiedAt: null,
  grants: [RoleGrant(role: 'DRIVER', status: 'ACTIVE')],
);

OpenRide _open(String id, CustomerRatingSummary? rating) => OpenRide(
  id: id,
  status: 'NEGOTIATING',
  pickup: const RidePoint(lat: 16.0544, lng: 108.2022, label: '123 Lê Lợi'),
  dropoff: const RidePoint(lat: 16.0471, lng: 108.2062, label: 'Sân bay'),
  offeredFareVnd: 42000,
  referenceFareVnd: 40000,
  expiresAt: '2030-01-01T00:00:00.000Z',
  offerCount: 0,
  customerRating: rating,
);

/// Drivers see the rider's rating on the open-ride list (inDrive).
void main() {
  testWidgets('open ride cards show the customer rating', (tester) async {
    final rides = FakeRideClient()
      ..openRides = [
        _open('ride-a', const CustomerRatingSummary(average: 4.6, count: 12)),
        _open('ride-b', null),
      ];
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
    expect(
      find.descendant(
        of: find.byKey(const Key('driver-open-customer-rating-ride-a')),
        matching: find.textContaining('4.6'),
      ),
      findsOneWidget,
    );
    expect(
      find.byKey(const Key('driver-open-customer-rating-ride-b')),
      findsOneWidget,
    );
  });
}
