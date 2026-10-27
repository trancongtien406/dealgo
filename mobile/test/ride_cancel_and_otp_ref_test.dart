import 'package:dealgo/core/format/short_ref.dart';
import 'package:dealgo/features/identity/domain/entities/user_profile.dart';
import 'package:dealgo/features/ride/domain/entities/ride_models.dart';
import 'package:dealgo/features/ride/presentation/utils/ride_routes.dart';
import 'package:dealgo/l10n/app_localizations_en.dart';
import 'package:dealgo/l10n/app_localizations_vi.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'support/auth_test_harness.dart';
import 'support/fake_ride_client.dart';

const _customer = UserProfile(
  id: 'cust-1',
  phone: '+84909990101',
  email: null,
  phoneVerifiedAt: '2026-10-25T06:00:00.000Z',
  emailVerifiedAt: null,
  grants: [],
);

RideView _ride(RideStatus status) => RideView(
  id: 'ride-1',
  status: status,
  pickup: const RidePoint(lat: 16.0678, lng: 108.2208, label: 'Hải Châu'),
  dropoff: const RidePoint(lat: 16.0612, lng: 108.2270, label: 'Cầu Rồng'),
  offeredFareVnd: 22000,
  referenceFareVnd: 22000,
  agreedFareVnd: null,
  assignedDriverId: null,
  selectedOfferId: null,
  expiresAt: '2030-01-01T00:00:00.000Z',
  offers: const [],
  vehicleClassCode: 'MOTORBIKE',
);

Future<void> _openCancel(WidgetTester tester, FakeRideClient rides) async {
  await tester.binding.setSurfaceSize(const Size(400, 1400));
  addTearDown(() => tester.binding.setSurfaceSize(null));
  await pumpSignedIn(tester, profile: _customer, rideClient: rides);
  final context = tester.element(find.byType(Scaffold).first);
  GoRouter.of(context).push(RideRoutes.cancel('ride-1'));
  await tester.pumpAndSettle();
  await tester.tap(find.byKey(const Key('ride-cancel-reason-changed_plans')));
  await tester.pump();
  await tester.tap(find.byKey(const Key('ride-cancel-confirm')));
  await tester.pumpAndSettle();
}

/// Regressions found on the simulator walk.
void main() {
  test('driver OTP hint shows a single # before the ride ref', () {
    final ref = shortRef('8f1c-00b5be9b');
    expect(AppLocalizationsVi().driverOtpValidFor(ref), isNot(contains('##')));
    expect(AppLocalizationsEn().driverOtpValidFor(ref), isNot(contains('##')));
    expect(AppLocalizationsVi().driverOtpValidFor(ref), endsWith('#BE9B'));
  });

  testWidgets('after a successful cancel, "keep this ride" is gone', (
    tester,
  ) async {
    final rides = FakeRideClient()
      ..onGet = ((_) => _ride(RideStatus.negotiating))
      ..onCancel = ((_) => _ride(RideStatus.cancelled));
    await _openCancel(tester, rides);
    expect(find.byKey(const Key('ride-cancel-done')), findsOneWidget);
    expect(find.byKey(const Key('ride-cancel-keep')), findsNothing);
    expect(find.byKey(const Key('ride-cancel-confirm')), findsNothing);
  });

  testWidgets('a failed cancel keeps the confirm button for retry', (
    tester,
  ) async {
    final rides = FakeRideClient()
      ..onGet = ((_) => _ride(RideStatus.negotiating))
      ..cancelError = Exception('network');
    await _openCancel(tester, rides);
    expect(find.byKey(const Key('ride-cancel-confirm')), findsOneWidget);
    expect(find.byKey(const Key('ride-cancel-keep')), findsOneWidget);
  });
}
