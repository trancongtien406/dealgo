import 'dart:io';

import 'package:dealgo/core/config/app_env.dart';
import 'package:dealgo/core/maps/placeholder_map_port.dart';
import 'package:dealgo/core/maps/tile_map_port.dart';
import 'package:dealgo/features/places/data/places_remote_datasource.dart';
import 'package:dealgo/features/places/domain/place.dart';
import 'package:dealgo/features/pricing/data/pricing_remote_datasource.dart';
import 'package:dealgo/features/ride/domain/entities/ride_models.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/auth_test_harness.dart';
import 'support/fake_identity_client.dart';
import 'support/fake_location.dart';
import 'support/fake_ride_client.dart';
import 'support/visual_shot.dart';

const _airport = PlaceOption(
  name: 'Sân bay Quốc tế Đà Nẵng',
  address: 'Nguyễn Văn Linh, Hải Châu, Đà Nẵng',
  lat: 16.0439,
  lng: 108.1994,
  source: PlaceSource.recent,
);

FakeRideClient _rides({String expiresAt = '2030-01-01T00:00:00.000Z'}) {
  final client = FakeRideClient();
  client.onCreate = (request) {
    final ride = RideView(
      id: 'ride-1',
      status: RideStatus.negotiating,
      pickup: request.pickup,
      dropoff: request.dropoff,
      offeredFareVnd: request.offeredFareVnd,
      referenceFareVnd: 40000,
      agreedFareVnd: null,
      assignedDriverId: null,
      selectedOfferId: null,
      expiresAt: expiresAt,
      offers: const [],
    );
    client.onGet = (_) => ride;
    return ride;
  };
  return client;
}

/// Phone-sized iOS screen (status bar + home indicator).
void _phone(WidgetTester tester) {
  tester.view
    ..physicalSize = const Size(390, 844)
    ..devicePixelRatio = 1
    ..padding = const FakeViewPadding(top: 47, bottom: 34)
    ..viewPadding = const FakeViewPadding(top: 47, bottom: 34);
  addTearDown(tester.view.reset);
}

Future<void> _openMap(WidgetTester tester, FakeRideClient rides) async {
  await pumpSignedIn(
    tester,
    profile: customerProfile,
    rideClient: rides,
    locationOverride: FakeLocationService(),
    places: FakePlacesRemoteDataSource(recent: [_airport]),
    pricing: FakePricingRemoteDataSource(fixedReferenceVnd: 42000),
  );
  await tester.tap(navLabel('Đặt'));
  await tester.pumpAndSettle();
  await tester.tap(find.text(_airport.name));
  await tester.pumpAndSettle();
}

Future<void> _openFare(WidgetTester tester) async {
  await tester.ensureVisible(find.byKey(const Key('ride-open-route-overview')));
  await tester.tap(find.byKey(const Key('ride-open-route-overview')));
  await tester.pumpAndSettle();
}

Future<void> _submit(WidgetTester tester) async {
  await tester.ensureVisible(find.byKey(const Key('ride-submit-fare')));
  await tester.tap(find.byKey(const Key('ride-submit-fare')));
  await tester.pumpAndSettle();
}

void main() {
  setUp(() {
    adminMapboxToken = '';
    // flutter_map's tile cache asks path_provider for a directory.
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('plugins.flutter.io/path_provider'),
          (_) async => Directory.systemTemp.path,
        );
  });
  tearDown(() => adminMapboxToken = '');

  testWidgets('a token that arrives after launch switches open maps to live '
      'tiles without a restart', (tester) async {
    _phone(tester);
    await loadShotFonts(tester);
    await _openMap(tester, _rides());
    await _openFare(tester);
    expect(find.byType(PlaceholderMapView), findsOneWidget);
    expect(find.byType(TileMapView), findsNothing);
    await saveShot(tester, 'A1-fare-no-token-placeholder');

    adminMapboxToken = 'pk.test-token';
    await tester.pump();
    expect(find.byType(PlaceholderMapView), findsNothing);
    final live = tester.widget<TileMapView>(find.byType(TileMapView));
    expect(live.urlTemplate, contains('api.mapbox.com'));
    expect(live.urlTemplate, contains('pk.test-token'));
    await saveShot(tester, 'A2-fare-late-token-live-tiles');

    // Cleared in Admin → clean placeholder again, never broken tiles.
    adminMapboxToken = '';
    await tester.pump();
    expect(find.byType(TileMapView), findsNothing);
    expect(find.byType(PlaceholderMapView), findsOneWidget);
  });

  testWidgets('a token set before the first frame builds live maps directly', (
    tester,
  ) async {
    adminMapboxToken = 'pk.cached';
    _phone(tester);
    await _openMap(tester, _rides());
    expect(find.byType(TileMapView), findsOneWidget);
    expect(find.byType(PlaceholderMapView), findsNothing);
  });

  testWidgets('back is visible before, during and after the driver search', (
    tester,
  ) async {
    _phone(tester);
    await loadShotFonts(tester);
    await _openMap(tester, _rides());
    expect(find.byKey(const Key('ride-map-back')), findsOneWidget);
    await saveShot(tester, 'B1-map-back');

    await _openFare(tester);
    expect(find.byKey(const Key('ride-fare-back')), findsOneWidget);
    await saveShot(tester, 'B2-fare-before-search-back');

    await _submit(tester);
    expect(find.byKey(const Key('ride-matching-back')), findsOneWidget);
    await saveShot(tester, 'B3-searching-back');

    // Back leaves the search screen (the request keeps running).
    await tester.tap(find.byKey(const Key('ride-matching-back')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('ride-fare-back')), findsOneWidget);

    await tester.tap(find.byKey(const Key('ride-fare-back')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('ride-map-back')), findsOneWidget);
  });

  testWidgets('an expired search still offers back', (tester) async {
    _phone(tester);
    await loadShotFonts(tester);
    await _openMap(tester, _rides(expiresAt: '2020-01-01T00:00:00.000Z'));
    await _openFare(tester);
    await _submit(tester);
    expect(find.byKey(const Key('header-back')), findsOneWidget);
    await saveShot(tester, 'B4-search-timeout-back');
  });
}
