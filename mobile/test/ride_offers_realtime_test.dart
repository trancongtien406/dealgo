import 'package:dealgo/core/realtime/fake_snapshot_realtime.dart';
import 'package:dealgo/core/realtime/realtime_refresh_watcher.dart';
import 'package:dealgo/core/realtime/snapshot_realtime.dart';
import 'package:dealgo/core/realtime/socket_snapshot_realtime.dart';
import 'package:dealgo/features/ride/domain/entities/ride_models.dart';
import 'package:dealgo/features/ride/presentation/pages/ride_offers_page.dart';
import 'package:dealgo/features/ride/presentation/utils/ride_routes.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'support/auth_test_harness.dart';
import 'support/fake_identity_client.dart';
import 'support/fake_ride_client.dart';

/// DEC-PROD-031 rev 2026-10-24: customer bid/offer screens run on the socket, not a poll.
void main() {
  testWidgets(
    'matching: no requests while silent for 60s; rideOffers hint opens offers; reconnect refetches once',
    (tester) async {
      var offers = const <RideOffer>[];
      final realtime = FakeSnapshotRealtime();
      final rides = FakeRideClient()..onGet = (_) => _ride(offers: offers);
      await tester.binding.setSurfaceSize(const Size(400, 1800));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await pumpSignedIn(
        tester,
        profile: customerProfile,
        rideClient: rides,
        realtime: realtime,
      );
      final context = tester.element(find.byType(Scaffold).first);
      GoRouter.of(context).push(RideRoutes.matching('ride-1'));
      await tester.pumpAndSettle();

      expect(
        realtime.subscribed,
        containsAll(['ride:ride-1', 'ride-offers:ride-1']),
      );
      final baseline = rides.getCalls.length;
      await tester.pump(const Duration(seconds: 60));
      await tester.pumpAndSettle();
      expect(rides.getCalls.length, baseline, reason: 'no polling');

      realtime.emitReconnect();
      await tester.pumpAndSettle();
      expect(
        rides.getCalls.length,
        baseline + 1,
        reason: 'reconnect → exactly one REST snapshot',
      );

      // A hint for another ride is ignored.
      realtime.emitRideOffers(
        const RideOffersHint(
          rideId: 'other',
          reason: 'OFFER',
          status: 'NEGOTIATING',
          revision: 'r',
        ),
      );
      await tester.pumpAndSettle();
      expect(rides.getCalls.length, baseline + 1);

      offers = const [
        RideOffer(
          id: 'offer-1',
          driverId: 'driver-1',
          amountVnd: 45000,
          kind: RideOfferKind.counter,
          status: RideOfferStatus.pending,
          expiresAt: '2030-01-01T00:00:00.000Z',
        ),
      ];
      realtime.emitRideOffers(
        const RideOffersHint(
          rideId: 'ride-1',
          reason: 'OFFER',
          status: 'NEGOTIATING',
          revision: 'r2',
        ),
      );
      await tester.pumpAndSettle();
      expect(rides.getCalls.length, greaterThan(baseline + 1));
      expect(
        find.byType(RideOffersPage),
        findsOneWidget,
        reason: 'first offer surfaces the offers list',
      );
      // Offers page joins the same customer-only rooms; 60s more silence → no polling there either.
      final onOffers = rides.getCalls.length;
      await tester.pump(const Duration(seconds: 60));
      await tester.pumpAndSettle();
      expect(rides.getCalls.length, onOffers);
    },
  );

  test(
    'watcher coalesces a burst of hints and never overlaps refreshes',
    () async {
      final realtime = FakeSnapshotRealtime();
      var calls = 0;
      var inFlight = 0;
      var maxInFlight = 0;
      final watcher = RealtimeRefreshWatcher(
        realtime: realtime,
        rooms: const [RideOffersRoom('r1')],
        refresh: () async {
          calls += 1;
          inFlight += 1;
          maxInFlight = inFlight > maxInFlight ? inFlight : maxInFlight;
          await Future<void>.delayed(const Duration(milliseconds: 10));
          inFlight -= 1;
        },
        matchesRideOffers: (h) => h.rideId == 'r1',
      );
      await watcher.start(accessToken: 't', initialRefresh: false);
      for (var i = 0; i < 5; i++) {
        realtime.emitRideOffers(
          RideOffersHint(
            rideId: 'r1',
            reason: 'OFFER',
            status: 'NEGOTIATING',
            revision: '$i',
          ),
        );
      }
      await Future<void>.delayed(const Duration(milliseconds: 80));
      expect(calls, 2);
      expect(maxInFlight, 1);
      await watcher.stop();
      expect(realtime.subscribed, isEmpty);
      realtime.emitRideOffers(
        const RideOffersHint(
          rideId: 'r1',
          reason: 'OFFER',
          status: 'NEGOTIATING',
          revision: 'x',
        ),
      );
      await Future<void>.delayed(const Duration(milliseconds: 20));
      expect(calls, 2);
    },
  );

  test('parses rideOffers and driverLocation heading payloads', () {
    final hint = parseRideOffersHint({
      'rideId': 'r1',
      'reason': 'SELECTED',
      'status': 'ASSIGNED',
      'revision': 'v',
      'offers': [],
    });
    expect(hint?.reason, 'SELECTED');
    expect(parseRideOffersHint({'rideId': 1}), isNull);
    final loc = parseDriverLocationHint({
      'aggregateType': 'Ride',
      'aggregateId': 'r1',
      'lat': 10.0,
      'lng': 106.0,
      'at': '2026-10-24T03:00:00Z',
      'heading': 90,
      'speedMps': 8.5,
    });
    expect(loc?.heading, 90);
    expect(loc?.speedMps, 8.5);
  });
}

RideView _ride({List<RideOffer> offers = const []}) => RideView(
  id: 'ride-1',
  status: RideStatus.negotiating,
  pickup: const RidePoint(lat: 16.0544, lng: 108.2022, label: 'Hải Châu'),
  dropoff: const RidePoint(lat: 16.0439, lng: 108.1994, label: 'Sân bay'),
  offeredFareVnd: 42000,
  referenceFareVnd: 40000,
  agreedFareVnd: null,
  assignedDriverId: null,
  selectedOfferId: null,
  expiresAt: '2030-01-01T00:00:00.000Z',
  offers: offers,
  vehicleClassCode: 'MOTORBIKE',
);
