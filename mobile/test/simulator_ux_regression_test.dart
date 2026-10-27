import 'package:dealgo/features/identity/domain/entities/auth_state.dart';
import 'package:dealgo/features/identity/presentation/cubit/auth_cubit.dart';
import 'package:dealgo/features/onboarding/presentation/cubit/driver_kyc_cubit.dart';
import 'package:dealgo/features/ride/domain/entities/ride_models.dart';
import 'package:dealgo/features/ride/presentation/utils/ride_routes.dart';
import 'package:dealgo/features/shell/presentation/account_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'support/auth_test_harness.dart';
import 'support/fake_identity_client.dart';
import 'support/fake_ride_client.dart';

/// UX regressions found on the simulators.
void main() {
  test('profile header shows the name; phone only when no name', () {
    expect(
      accountProfileTitle('Nguyen Van Test', '+84909990101'),
      'Nguyen Van Test',
    );
    expect(accountProfileTitle('  ', '+84909990101'), '+84909990101');
    expect(accountProfileTitle(null, null), isNull);
  });

  test(
    'driver services: first tap on Chở khách ticks it (nothing preselected)',
    () {
      final cubit = DriverKycCubit(useMock: true);
      expect(cubit.state.rideService, isFalse);
      expect(cubit.state.foodService, isFalse);
      expect(cubit.state.canContinueServices, isFalse);
      cubit.toggleRide();
      expect(cubit.state.rideService, isTrue);
      expect(cubit.state.foodService, isFalse);
      expect(cubit.state.canContinueServices, isTrue);
    },
  );

  testWidgets('logout asks for confirmation; cancel keeps the session', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(400, 1800));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await pumpSignedIn(tester, profile: customerProfile);
    await tester.tap(navLabel('Tôi'));
    await tester.pumpAndSettle();
    expect(find.text('Nguyễn Văn A'), findsWidgets);
    expect(find.text('+84911111111'), findsNothing);
    await tester.tap(find.byKey(const Key('account-signout')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('account-signout-confirm')), findsOneWidget);
    await tester.tapAt(const Offset(5, 5)); // dismiss
    await tester.pumpAndSettle();
    final ctx = tester.element(find.byType(AccountPage));
    expect(ctx.read<AuthCubit>().state, isA<AuthSignedIn>());
    await tester.tap(find.byKey(const Key('account-signout')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('account-signout-confirm')));
    await tester.pumpAndSettle();
    expect(find.byType(AccountPage), findsNothing);
  });

  testWidgets('choosing a driver offer asks for confirmation first', (
    tester,
  ) async {
    final rides = FakeRideClient()..onGet = (_) => _ride();
    await tester.binding.setSurfaceSize(const Size(400, 1800));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await pumpSignedIn(tester, profile: customerProfile, rideClient: rides);
    GoRouter.of(tester.element(find.byType(Scaffold).first))
        .push(RideRoutes.offers('ride-1'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('ride-offer-offer-1')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('ride-select-offer')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('ride-offer-confirm')), findsOneWidget);
    expect(rides.selectCalls, isEmpty, reason: 'nothing sent before confirm');
    await tester.tap(find.byKey(const Key('ride-offer-confirm')));
    await tester.pumpAndSettle();
    expect(rides.selectCalls, hasLength(1));
  });
}

RideView _ride() => const RideView(
  id: 'ride-1',
  status: RideStatus.negotiating,
  pickup: RidePoint(lat: 16.0544, lng: 108.2022, label: 'Hải Châu'),
  dropoff: RidePoint(lat: 16.0439, lng: 108.1994, label: 'Sân bay'),
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
      amountVnd: 45000,
      kind: RideOfferKind.counter,
      status: RideOfferStatus.pending,
      expiresAt: '2030-01-01T00:00:00.000Z',
    ),
  ],
  vehicleClassCode: 'MOTORBIKE',
);
