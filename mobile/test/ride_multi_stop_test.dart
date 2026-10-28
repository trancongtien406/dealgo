import 'package:dealgo/features/driver/presentation/utils/driver_routes.dart';
import 'package:dealgo/features/identity/domain/entities/user_profile.dart';
import 'package:dealgo/features/live_location/data/map_routing_remote_datasource.dart';
import 'package:dealgo/core/maps/map_lat_lng.dart';
import 'package:dealgo/features/ride/data/datasources/ride_stops_client_impl.dart';
import 'package:dealgo/features/ride/data/models/ride_models.dart';
import 'package:dealgo/features/ride/domain/entities/ride_models.dart';
import 'package:dealgo/features/ride/presentation/widgets/ride_widgets.dart';
import 'package:dealgo/features/ride/presentation/utils/ride_routes.dart';
import 'package:dealgo/core/maps/map_markers.dart';
import 'package:dealgo/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'support/auth_test_harness.dart';
import 'support/fake_food_client.dart';
import 'support/fake_identity_client.dart';
import 'support/fake_ride_client.dart';

const _driver = UserProfile(
  id: 'driver-1',
  phone: '+84933333333',
  email: null,
  phoneVerifiedAt: '2026-10-13T16:00:00.000Z',
  emailVerifiedAt: null,
  grants: [RoleGrant(role: 'DRIVER', status: 'ACTIVE')],
);

const _pickup = RidePoint(lat: 16.0544, lng: 108.2022, label: 'Hải Châu');
const _dropoff = RidePoint(lat: 16.0439, lng: 108.1994, label: 'Sân bay');
const _stop1 = RidePoint(lat: 16.06, lng: 108.21, label: 'Chợ Hàn');
const _stop2 = RidePoint(lat: 16.07, lng: 108.22, label: 'Cầu Rồng');

RideView _inTrip({List<RideStop>? stops}) => RideView(
  id: 'ride-ms',
  status: RideStatus.inTrip,
  pickup: _pickup,
  dropoff: _dropoff,
  offeredFareVnd: 60000,
  referenceFareVnd: 60000,
  agreedFareVnd: 60000,
  assignedDriverId: 'driver-1',
  selectedOfferId: 'offer-1',
  expiresAt: '2030-01-01T00:00:00.000Z',
  offers: const [],
  vehicleClassCode: 'MOTORBIKE',
  routeVersion: 2,
  stops:
      stops ??
      const [RideStop(seq: 1, point: _stop1), RideStop(seq: 2, point: _stop2)],
);

Map<String, Object?> _rideJson({List<Object?>? stops, int waitFee = 0}) => {
  'id': 'ride-1',
  'status': 'IN_TRIP',
  'pickup': {'lat': 16.05, 'lng': 108.2, 'label': 'A'},
  'dropoff': {'lat': 16.04, 'lng': 108.19, 'label': 'B'},
  'offeredFareVnd': 50000,
  'referenceFareVnd': 50000,
  'agreedFareVnd': 50000,
  'expiresAt': '2030-01-01T00:00:00.000Z',
  'offers': const [],
  'vehicleClassCode': 'MOTORBIKE',
  'stops': ?stops,
  'routeVersion': 3,
  'currentStopSeq': 2,
  'stopFeeVnd': 5000,
  'waitFeeVnd': waitFee,
};

Future<void> _go(WidgetTester tester, String location) async {
  GoRouter.of(tester.element(find.byType(Navigator).first)).go(location);
  await tester.pumpAndSettle();
}

void main() {
  group('multi-stop models', () {
    test('ride view parses stops in seq order with progress', () {
      final ride = RideViewModel.fromJson(
        _rideJson(
          stops: [
            {
              'seq': 2,
              'lat': 16.07,
              'lng': 108.22,
              'label': 'S2',
              'arrivedAt': null,
              'departedAt': null,
            },
            {
              'seq': 1,
              'lat': 16.06,
              'lng': 108.21,
              'label': 'S1',
              'arrivedAt': '2026-10-28T01:00:00.000Z',
              'departedAt': '2026-10-28T01:03:00.000Z',
            },
            {'seq': 3, 'label': 'broken'},
          ],
          waitFee: 2000,
        ),
      ).toEntity();
      expect([for (final s in ride.stops) s.point.label], ['S1', 'S2']);
      expect(ride.stops.first.state, RideStopState.departed);
      expect(ride.currentStop?.seq, 2);
      expect(ride.routeVersion, 3);
      expect(ride.currentStopSeq, 2);
      expect(ride.stopFeeVnd, 5000);
      // Cash due includes the stop waiting fee.
      expect(ride.cashDueVnd, 52000);
    });

    test('legacy single-destination payload reads as no stops', () {
      final ride = RideViewModel.fromJson(_rideJson()).toEntity();
      expect(ride.stops, isEmpty);
      expect(ride.currentStop, isNull);
      expect(ride.cashDueVnd, 50000);
    });

    test('model round-trips through JSON', () {
      final model = RideViewModel.fromEntity(_inTrip());
      final again = RideViewModel.fromJson(model.toJson()).toEntity();
      expect(again.stops.length, 2);
      expect(again.routeVersion, 2);
    });

    test('create body omits stops when empty and sends them in order', () {
      final single = CreateRideBody(
        pickup: RidePointModel.fromEntity(_pickup),
        dropoff: RidePointModel.fromEntity(_dropoff),
        offeredFareVnd: 40000,
        vehicleClassCode: 'MOTORBIKE',
      ).toJson();
      expect(single.containsKey('stops'), isFalse);
      final multi = CreateRideBody(
        pickup: RidePointModel.fromEntity(_pickup),
        dropoff: RidePointModel.fromEntity(_dropoff),
        offeredFareVnd: 40000,
        vehicleClassCode: 'MOTORBIKE',
        stops: [
          RidePointModel.fromEntity(_stop1),
          RidePointModel.fromEntity(_stop2),
        ],
      ).toJson();
      final stops = multi['stops']! as List;
      expect((stops.first as Map)['label'], 'Chợ Hàn');
      expect((stops.last as Map)['label'], 'Cầu Rồng');
    });

    test('offer body carries routeVersion only when known', () {
      expect(const SubmitRideOfferBody(amountVnd: 1).toJson(), {
        'amountVnd': 1,
      });
      expect(
        const SubmitRideOfferBody(amountVnd: 1, routeVersion: 4).toJson(),
        {'amountVnd': 1, 'routeVersion': 4},
      );
    });

    test('open ride parses stops and route version', () {
      final open = OpenRideModel.fromJson({
        'id': 'r',
        'status': 'NEGOTIATING',
        'pickup': {'lat': 1, 'lng': 2, 'label': 'A'},
        'dropoff': {'lat': 3, 'lng': 4, 'label': 'B'},
        'offeredFareVnd': 1000,
        'referenceFareVnd': 1000,
        'expiresAt': '2030-01-01T00:00:00.000Z',
        'offerCount': 0,
        // Open list sends ordered stops without seq.
        'stops': [
          {'lat': 5, 'lng': 6, 'label': 'S'},
        ],
        'routeVersion': 1,
      }).toEntity();
      expect(open.stops.single.label, 'S');
      expect(open.routeVersion, 1);
    });

    test('settings: flags off hide stops; most generous service wins', () {
      expect(parseMultiStopSettings(null).maxStopsAnyService, 0);
      final off = parseMultiStopSettings({
        'BIKE': {'enabled': false, 'maxStops': 1},
        'CAR': {'enabled': false, 'maxStops': 2},
      });
      expect(off.maxStopsAnyService, 0);
      final on = parseMultiStopSettings({
        'BIKE': {'enabled': true, 'maxStops': 1, 'stopFeeVnd': 5000},
        'CAR': {'enabled': true, 'maxStops': 2, 'stopFeeVnd': 10000},
      });
      expect(on.maxStopsAnyService, 2);
      expect(on.forVehicleClass('MOTORBIKE').stopFeeVnd, 5000);
      expect(on.forVehicleClass('CAR_4').maxStops, 2);
      final zero = parseMultiStopSettings({
        'BIKE': {'enabled': true, 'maxStops': 0},
      });
      expect(zero.maxStopsAnyService, 0);
    });

    test('RidePlaces keeps stops through quote/class changes', () {
      const places = RidePlaces(
        pickup: _pickup,
        dropoff: _dropoff,
        stops: [_stop1],
      );
      expect(places.canContinue, isTrue);
      const blank = RidePlaces(
        pickup: _pickup,
        dropoff: _dropoff,
        stops: [RidePoint(lat: 1, lng: 1, label: ' ')],
      );
      expect(blank.canContinue, isFalse);
    });
  });

  test('fake routing records via and fake stops client advances', () async {
    final routing = FakeMapRoutingRemoteDataSource();
    await routing.route(
      accessToken: 't',
      from: const MapLatLng(lat: 1, lng: 1),
      to: const MapLatLng(lat: 2, lng: 2),
      via: const [MapLatLng(lat: 1.5, lng: 1.5)],
    );
    expect(routing.calls, hasLength(1));

    final client = FakeRideStopsClient(ride: _inTrip());
    var ride = await client.arriveStop(
      accessToken: 't',
      rideId: 'ride-ms',
      seq: 1,
    );
    expect(ride.stops.first.state, RideStopState.arrived);
    ride = await client.departStop(accessToken: 't', rideId: 'ride-ms', seq: 1);
    expect(ride.currentStop?.seq, 2);
    ride = await client.updateStops(
      accessToken: 't',
      rideId: 'ride-ms',
      stops: const [_stop2],
    );
    expect(ride.stops.single.point.label, 'Cầu Rồng');
    expect(ride.routeVersion, 3);
  });

  testWidgets('stop list shows every stop between pickup and drop-off', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        locale: Locale('vi'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: RideStopList(
            pickup: 'Hải Châu',
            dropoff: 'Sân bay',
            stops: ['Chợ Hàn', 'Cầu Rồng'],
            stopStates: [RideStopState.departed, RideStopState.pending],
          ),
        ),
      ),
    );
    expect(find.byKey(const Key('ride-multi-stop-list')), findsOneWidget);
    expect(find.text('Chợ Hàn'), findsOneWidget);
    expect(find.text('Cầu Rồng'), findsOneWidget);
    expect(find.text('Điểm dừng 1 · Đã xong'), findsOneWidget);
    expect(find.text('Điểm dừng 2 · Chưa đến'), findsOneWidget);
  });

  testWidgets('without stops the classic two-row list is kept', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        locale: Locale('vi'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: RideStopList(pickup: 'Hải Châu', dropoff: 'Sân bay'),
        ),
      ),
    );
    expect(find.byKey(const Key('ride-multi-stop-list')), findsNothing);
  });

  testWidgets('driver arrives and leaves each stop before completing', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(400, 1800));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final stops = FakeRideStopsClient(ride: _inTrip());
    final rides = FakeRideClient()..onGet = (_) => _inTrip();
    await pumpSignedIn(
      tester,
      profile: _driver,
      rideClient: rides,
      rideStopsClient: stops,
      foodClient: FakeFoodClient(),
    );
    await _go(tester, DriverRoutes.active('ride-ms'));
    expect(find.byKey(const Key('driver-active-stops')), findsOneWidget);
    expect(find.text('Chợ Hàn'), findsWidgets);
    expect(find.byKey(const Key('driver-active-complete')), findsNothing);

    await tester.tap(find.byKey(const Key('driver-stop-arrive-1')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('driver-stop-depart-1')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('driver-stop-arrive-2')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('driver-stop-depart-2')));
    await tester.pumpAndSettle();
    expect(stops.calls, ['arrive:1', 'depart:1', 'arrive:2', 'depart:2']);
    // Every stop done: the normal complete button comes back.
    expect(find.byKey(const Key('driver-active-complete')), findsOneWidget);
  });

  testWidgets('single-destination ride has no stop panel or stop buttons', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(400, 1800));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final rides = FakeRideClient()..onGet = (_) => _inTrip(stops: const []);
    await pumpSignedIn(
      tester,
      profile: _driver,
      rideClient: rides,
      foodClient: FakeFoodClient(),
    );
    await _go(tester, DriverRoutes.active('ride-ms'));
    expect(find.byKey(const Key('driver-active-stops')), findsNothing);
    expect(find.byKey(const Key('driver-active-complete')), findsOneWidget);
  });

  group('stop map pins', () {
    test('middle markers of a ride with stops are numbered stops', () {
      DealGoMapPinKind k(int i, int n) =>
          mapPinKindFor(i, firstMarkerIsPickup: true, count: n);
      expect(k(0, 4), DealGoMapPinKind.pickup);
      expect(k(1, 4), DealGoMapPinKind.stop);
      expect(k(2, 4), DealGoMapPinKind.stop);
      expect(k(3, 4), DealGoMapPinKind.dropoff);
      expect(k(1, 2), DealGoMapPinKind.dropoff);
      expect(
        mapPinKindFor(
          1,
          firstMarkerIsPickup: true,
          style: MapStopStyle.food,
          count: 3,
        ),
        DealGoMapPinKind.home,
      );
    });

    testWidgets('stop pin shows its number and label', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          locale: Locale('vi'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Center(
            child: DealGoMapPin(kind: DealGoMapPinKind.stop, number: 2),
          ),
        ),
      );
      expect(find.byKey(const Key('map-pin-stop-2')), findsOneWidget);
      expect(find.text('Dừng 2'), findsOneWidget);
    });
  });

  RideView negotiatingWithOffer() => RideView(
    id: 'ride-neg',
    status: RideStatus.negotiating,
    pickup: _pickup,
    dropoff: _dropoff,
    offeredFareVnd: 50000,
    referenceFareVnd: 50000,
    agreedFareVnd: null,
    assignedDriverId: null,
    selectedOfferId: null,
    expiresAt: '2030-01-01T00:00:00.000Z',
    offers: const [
      RideOffer(
        id: 'offer-1',
        driverId: 'driver-1',
        amountVnd: 55000,
        kind: RideOfferKind.counter,
        status: RideOfferStatus.pending,
        expiresAt: '2030-01-01T00:00:00.000Z',
      ),
    ],
    vehicleClassCode: 'MOTORBIKE',
    routeVersion: 1,
    stops: const [
      RideStop(seq: 1, point: _stop1),
      RideStop(seq: 2, point: _stop2),
    ],
  );

  const enabled = MultiStopSettings(
    bike: MultiStopPolicy(
      enabled: true,
      maxStops: 2,
      stopFeeVnd: 5000,
      freeWaitMinutes: 5,
      waitFeeVndPerMinute: 1000,
    ),
    car: MultiStopPolicy.disabled,
  );

  testWidgets('customer edits stops while negotiating after confirming', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(400, 1800));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final stops = FakeRideStopsClient(
      settings: enabled,
      ride: negotiatingWithOffer(),
    );
    final rides = FakeRideClient()..onGet = (_) => negotiatingWithOffer();
    await pumpSignedIn(
      tester,
      profile: customerProfile,
      rideClient: rides,
      rideStopsClient: stops,
    );
    await _go(tester, RideRoutes.offers('ride-neg'));
    await tester.tap(find.byKey(const Key('ride-edit-stops')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('ride-edit-stops-sheet')), findsOneWidget);
    // Max reached: no add button.
    expect(find.byKey(const Key('ride-edit-stop-add')), findsNothing);
    await tester.tap(find.byKey(const Key('ride-edit-stop-up-1')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('ride-edit-stop-remove-1')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('ride-edit-stops-save')));
    await tester.pumpAndSettle();
    // Pending offers exist → confirmation first.
    await tester.tap(find.byKey(const Key('ride-edit-stops-confirm')));
    await tester.pumpAndSettle();
    expect(stops.calls, contains('update:1'));
    expect(stops.ride!.stops.single.point.label, 'Cầu Rồng');
    expect(stops.ride!.routeVersion, 2);
  });

  testWidgets('edit stops is hidden when the admin flag is off', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(400, 1800));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final rides = FakeRideClient()
      ..onGet = (_) => RideView(
        id: 'ride-x',
        status: RideStatus.negotiating,
        pickup: _pickup,
        dropoff: _dropoff,
        offeredFareVnd: 50000,
        referenceFareVnd: 50000,
        agreedFareVnd: null,
        assignedDriverId: null,
        selectedOfferId: null,
        expiresAt: '2030-01-01T00:00:00.000Z',
        offers: const [],
        vehicleClassCode: 'MOTORBIKE',
      );
    await pumpSignedIn(
      tester,
      profile: customerProfile,
      rideClient: rides,
      rideStopsClient: FakeRideStopsClient(),
    );
    await _go(tester, RideRoutes.offers('ride-x'));
    expect(find.byKey(const Key('ride-edit-stops')), findsNothing);
  });
}
