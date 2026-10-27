import 'dart:io';
import 'dart:ui' as ui;

import 'package:dealgo/app/dealgo_app.dart';
import 'package:dealgo/core/auth/post_auth_gate.dart';
import 'package:dealgo/core/auth/token_store.dart';
import 'package:dealgo/core/config/app_env.dart';
import 'package:dealgo/core/maps/create_map_port.dart';
import 'package:dealgo/core/maps/tile_map_port.dart';
import 'package:dealgo/core/mock/fake_identity_client.dart';
import 'package:dealgo/features/places/data/places_remote_datasource.dart';
import 'package:dealgo/features/places/domain/place.dart';
import 'package:dealgo/features/pricing/data/pricing_remote_datasource.dart';
import 'package:dealgo/features/ride/domain/entities/ride_models.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/fake_food_client.dart';
import 'support/fake_location.dart';
import 'support/fake_ride_client.dart';

const _out = 'build/smoke_ux';
const _airport = PlaceOption(
  name: 'Sân bay Quốc tế Đà Nẵng',
  address: 'Nguyễn Văn Linh, Hải Châu, Đà Nẵng',
  lat: 16.0439,
  lng: 108.1994,
  source: PlaceSource.recent,
);

RideView _nego([String id = 'ride-smoke']) => RideView(
  id: id,
  status: RideStatus.negotiating,
  pickup: const RidePoint(
    lat: 16.0544,
    lng: 108.2022,
    label: 'Vị trí hiện tại',
  ),
  dropoff: const RidePoint(
    lat: 16.0439,
    lng: 108.1994,
    label: 'Sân bay Quốc tế Đà Nẵng',
  ),
  offeredFareVnd: 42000,
  referenceFareVnd: 40000,
  agreedFareVnd: null,
  assignedDriverId: null,
  selectedOfferId: null,
  expiresAt: '2030-01-01T00:00:00.000Z',
  offers: const [],
);

void main() {
  test('maps env selects Mapbox Streets when MAPS_API_KEY is set', () {
    expect(mapboxStreetsTileUrl.contains('api.mapbox.com'), isTrue);
    expect(mapboxStreetsTileUrl.contains('streets-v12'), isTrue);
    if (mapsApiKey.trim().isEmpty) {
      return;
    }
    expect(useLiveMaps, isTrue);
    expect(effectiveMapTileUrl.contains('api.mapbox.com'), isTrue);
    expect(effectiveMapAttribution.toLowerCase(), contains('mapbox'));
    expect(createMapPort(), isA<TileMapPort>());
  });

  testWidgets('smoke map sheet fare waiting screenshots', (tester) async {
    tester.view.physicalSize = const Size(390 * 3, 844 * 3);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final rides = FakeRideClient()
      ..onCreate = ((_) => _nego())
      ..onGet = ((id) => _nego(id));

    final store = MemoryTokenStore();
    await store.write(
      const StoredTokens(accessToken: 'access', refreshToken: 'refresh'),
    );

    await tester.pumpWidget(
      RepaintBoundary(
        key: const Key('shot-root'),
        child: DealGoApp(
          identityClient: FakeIdentityClient(profile: customerProfile),
          tokenStore: store,
          foodClient: FakeFoodClient(),
          rideClient: rides,
          locationOverride: FakeLocationService(),
          places: FakePlacesRemoteDataSource(recent: [_airport]),
          pricing: FakePricingRemoteDataSource(fixedReferenceVnd: 42000),
          postAuthGate: PostAuthGate.seeded(
            profileSetupCompleted: true,
            permissionsCompleted: true,
          ),
          initialLocation: '/customer',
        ),
      ),
    );
    await tester.pumpAndSettle();
    await _shoot(tester, '5x-20-home');

    await tester.tap(find.text('Đặt').last);
    await tester.pumpAndSettle();
    await _shoot(tester, '5x-21-place-picker');

    await tester.tap(find.text(_airport.name));
    await tester.pumpAndSettle();
    await tester.pump(const Duration(seconds: 3));
    await _shoot(tester, '5x-22-map-sheet');

    expect(find.text('Chọn xe & đề xuất giá'), findsOneWidget);
    expect(find.byType(AppBar), findsNothing);

    await tester.ensureVisible(
      find.byKey(const Key('ride-open-route-overview')),
    );
    await tester.tap(find.byKey(const Key('ride-open-route-overview')));
    await tester.pumpAndSettle();
    await _shoot(tester, '5x-23-fare-sheet');

    // Redesign: the route overview sheet lists vehicle classes + one CTA with the fare.
    expect(find.text('Phương tiện'), findsOneWidget);
    expect(find.textContaining('Tìm tài xế ·'), findsOneWidget);
    expect(find.byType(AppBar), findsNothing);
    expect(find.byType(DraggableScrollableSheet), findsOneWidget);

    await tester.drag(
      find.byType(DraggableScrollableSheet),
      const Offset(0, -180),
    );
    await tester.pumpAndSettle();
    await _shoot(tester, '5x-24-fare-sheet-expanded');

    await tester.ensureVisible(find.byKey(const Key('ride-submit-fare')));
    await tester.tap(find.byKey(const Key('ride-submit-fare')));
    await tester.pumpAndSettle();
    await _shoot(tester, '5x-25-waiting');
    expect(find.byType(AppBar), findsNothing);
  });
}

Future<void> _shoot(WidgetTester tester, String name) async {
  final boundary = tester.renderObject<RenderRepaintBoundary>(
    find.byKey(const Key('shot-root')),
  );
  final bytes = await tester.runAsync(() async {
    final image = await boundary.toImage(pixelRatio: 1.5);
    final data = await image.toByteData(format: ui.ImageByteFormat.png);
    return data!.buffer.asUint8List();
  });
  Directory(_out).createSync(recursive: true);
  File('$_out/$name.png').writeAsBytesSync(bytes!);
}
