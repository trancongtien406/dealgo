import 'dart:typed_data';

import 'package:dealgo/core/config/app_env.dart';
import 'package:dealgo/core/maps/map_lat_lng.dart';
import 'package:dealgo/core/maps/tile_map_port.dart';
import 'package:dealgo/features/places/data/places_remote_datasource.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/auth_test_harness.dart';
import 'support/fake_identity_client.dart';
import 'support/fake_location.dart';

/// 1×1 transparent PNG so tile loading never touches the network.
final _pixel = Uint8List.fromList(const [
  0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, 0x00, 0x00, 0x00, 0x0D, //
  0x49, 0x48, 0x44, 0x52, 0x00, 0x00, 0x00, 0x01, 0x00, 0x00, 0x00, 0x01,
  0x08, 0x06, 0x00, 0x00, 0x00, 0x1F, 0x15, 0xC4, 0x89, 0x00, 0x00, 0x00,
  0x0A, 0x49, 0x44, 0x41, 0x54, 0x78, 0x9C, 0x63, 0x00, 0x01, 0x00, 0x00,
  0x05, 0x00, 0x01, 0x0D, 0x0A, 0x2D, 0xB4, 0x00, 0x00, 0x00, 0x00, 0x49,
  0x45, 0x4E, 0x44, 0xAE, 0x42, 0x60, 0x82,
]);

class _MemoryTiles extends TileProvider {
  _MemoryTiles();

  var requests = 0;

  @override
  ImageProvider getImage(TileCoordinates coordinates, TileLayer options) {
    requests++;
    return MemoryImage(_pixel);
  }
}

void main() {
  group('resolveTileUrlTemplate', () {
    test('accepts https XYZ templates and fills the key', () {
      expect(
        resolveTileUrlTemplate(
          'https://t.example.com/{z}/{x}/{y}.png?key={key}',
          apiKey: 'a b',
        ),
        'https://t.example.com/{z}/{x}/{y}.png?key=a%20b',
      );
      expect(
        resolveTileUrlTemplate(
          'https://t.example.com/{z}/{x}/{y}.png',
          apiKey: '',
        ),
        'https://t.example.com/{z}/{x}/{y}.png',
      );
    });

    test('rejects empty, http, incomplete or key-less templates', () {
      expect(resolveTileUrlTemplate('', apiKey: 'k'), isNull);
      expect(
        resolveTileUrlTemplate(
          'http://t.example.com/{z}/{x}/{y}.png',
          apiKey: '',
        ),
        isNull,
      );
      expect(
        resolveTileUrlTemplate('https://t.example.com/{z}/{x}.png', apiKey: ''),
        isNull,
      );
      expect(
        resolveTileUrlTemplate(
          'https://t.example.com/{z}/{x}/{y}.png?key={key}',
          apiKey: '',
        ),
        isNull,
      );
    });

    test('the default test build falls back to the placeholder', () {
      expect(useLiveMaps, isFalse);
      expect(effectiveMapTileUrl, isEmpty);
    });

    test('Mapbox streets template accepts a key', () {
      expect(
        resolveTileUrlTemplate(mapboxStreetsTileUrl, apiKey: 'pk.test'),
        contains('access_token=pk.test'),
      );
    });
  });

  testWidgets('TileMapPort renders live tiles, markers and attribution', (
    tester,
  ) async {
    final tiles = _MemoryTiles();
    final port = TileMapPort(
      urlTemplate: 'https://t.example.com/{z}/{x}/{y}.png',
      attribution: '© Tile provider',
      tileProvider: tiles,
    );
    await tester.pumpWidget(
      MaterialApp(
        home: SizedBox(
          width: 360,
          height: 400,
          child: port.buildMap(
            center: danangViewportCenter,
            markers: const [
              MapLatLng(lat: 16.0544, lng: 108.2022),
              MapLatLng(lat: 16.0678, lng: 108.2208),
            ],
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('map-live')), findsOneWidget);
    expect(find.byKey(const Key('map-live-marker-0')), findsOneWidget);
    expect(find.byKey(const Key('map-live-marker-1')), findsOneWidget);
    expect(find.text('© Tile provider'), findsOneWidget);
    expect(tiles.requests, greaterThan(0));
  });

  testWidgets('TileMapPort draws the live driver marker (DEC-PROD-031)', (
    tester,
  ) async {
    final port = TileMapPort(
      urlTemplate: 'https://t.example.com/{z}/{x}/{y}.png',
      tileProvider: _MemoryTiles(),
    );
    await tester.pumpWidget(
      MaterialApp(
        home: port.buildMap(
          center: danangViewportCenter,
          markers: const [MapLatLng(lat: 16.0544, lng: 108.2022)],
          driver: const MapLatLng(lat: 16.058, lng: 108.205),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('map-live-driver')), findsOneWidget);
    expect(find.byKey(const Key('map-live-attribution')), findsNothing);
  });

  testWidgets('home search opens food search with the typed query', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(400, 1600));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await pumpSignedIn(tester, profile: customerProfile);

    await tester.enterText(
      find.byKey(const Key('home-search-field')),
      'bún bò',
    );
    await tester.testTextInput.receiveAction(TextInputAction.search);
    await tester.pumpAndSettle();
    expect(find.text('Cửa hàng, món ăn: “bún bò”'), findsOneWidget);
    await tester.tap(find.byKey(const Key('home-search-food')));
    await tester.pumpAndSettle();

    final field = tester.widget<TextField>(
      find.byKey(const Key('food-search-field')),
    );
    expect(field.controller?.text, 'bún bò');
  });

  testWidgets('home search as destination books a ride to the picked place', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(400, 1600));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await pumpSignedIn(
      tester,
      profile: customerProfile,
      locationOverride: FakeLocationService(),
      places: FakePlacesRemoteDataSource(
        catalog: FakePlacesRemoteDataSource.sampleCatalog,
      ),
    );

    await tester.enterText(
      find.byKey(const Key('home-search-field')),
      'chợ hàn',
    );
    await tester.testTextInput.receiveAction(TextInputAction.search);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('home-search-place')));
    await tester.pumpAndSettle();

    // The picker opens pre-searched with the home query.
    expect(find.text('Chợ Hàn'), findsOneWidget);
    await tester.tap(find.byKey(const Key('place-result-0')));
    await tester.pumpAndSettle();

    expect(
      find.text('Chợ Hàn, 119 Trần Phú, Hải Châu, Đà Nẵng'),
      findsOneWidget,
    );
  });

  testWidgets('an empty home search does nothing', (tester) async {
    await pumpSignedIn(tester, profile: customerProfile);
    await tester.enterText(find.byKey(const Key('home-search-field')), '  ');
    await tester.testTextInput.receiveAction(TextInputAction.search);
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('home-search-food')), findsNothing);
  });
}
