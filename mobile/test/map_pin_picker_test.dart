import 'dart:async';
import 'dart:typed_data';

import 'package:dealgo/core/design_system/components/dealgo_primary_button.dart';
import 'package:dealgo/core/maps/map_controls.dart';
import 'package:dealgo/core/maps/map_lat_lng.dart';
import 'package:dealgo/core/maps/map_style.dart';
import 'package:dealgo/core/maps/tile_map_port.dart';
import 'package:dealgo/features/places/data/places_remote_datasource.dart';
import 'package:dealgo/features/places/data/reverse_geocode_cache.dart';
import 'package:dealgo/features/places/domain/place.dart';
import 'package:dealgo/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'support/auth_test_harness.dart';
import 'support/fake_identity_client.dart';
import 'support/fake_location.dart';

const _mapbox =
    'https://api.mapbox.com/styles/v1/mapbox/streets-v12/tiles/256/{z}/{x}/{y}@2x?access_token=k';

final _pixel = Uint8List.fromList(const [
  0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, 0x00, 0x00, 0x00, 0x0D, //
  0x49, 0x48, 0x44, 0x52, 0x00, 0x00, 0x00, 0x01, 0x00, 0x00, 0x00, 0x01,
  0x08, 0x06, 0x00, 0x00, 0x00, 0x1F, 0x15, 0xC4, 0x89, 0x00, 0x00, 0x00,
  0x0D, 0x49, 0x44, 0x41, 0x54, 0x78, 0x9C, 0x63, 0xF8, 0xCF, 0xC0, 0xF0,
  0x1F, 0x00, 0x05, 0x00, 0x01, 0xFF, 0x89, 0x99, 0x3D, 0x1D, 0x00, 0x00,
  0x00, 0x00, 0x49, 0x45, 0x4E, 0x44, 0xAE, 0x42, 0x60, 0x82,
]);

class _MemoryTiles extends TileProvider {
  @override
  ImageProvider getImage(TileCoordinates coordinates, TileLayer options) =>
      MemoryImage(_pixel);
}

/// Sample catalog plus a reverse lookup that counts calls.
class _CountingPlaces extends FakePlacesRemoteDataSource {
  _CountingPlaces() : super(catalog: FakePlacesRemoteDataSource.sampleCatalog);

  var reverses = 0;

  @override
  Future<PlaceOption?> reverse({
    required String accessToken,
    required double lat,
    required double lng,
  }) async {
    reverses++;
    return PlaceOption(
      name: 'Gần Chợ Hàn',
      address: 'Trần Phú, Hải Châu, Đà Nẵng',
      lat: lat,
      lng: lng,
      source: PlaceSource.search,
    );
  }
}

PlaceOption _place(String name, double lat, double lng) => PlaceOption(
  name: name,
  address: '',
  lat: lat,
  lng: lng,
  source: PlaceSource.search,
);

Future<void> _openBook(
  WidgetTester tester, {
  _CountingPlaces? places,
  bool denied = false,
}) async {
  await tester.binding.setSurfaceSize(const Size(400, 900));
  addTearDown(() => tester.binding.setSurfaceSize(null));
  await pumpSignedIn(
    tester,
    profile: customerProfile,
    places: places ?? _CountingPlaces(),
    locationOverride: denied
        ? FakeLocationService.denied()
        : FakeLocationService(),
  );
  await tester.tap(navLabel('Đặt'));
  await tester.pumpAndSettle();
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    reverseGeocodeCache.clear();
    mapStyle.value = DealGoMapStyle.standard;
  });

  group('map styles', () {
    test('derive satellite and dark from the Mapbox template', () {
      expect(mapStylesSupported(_mapbox), isTrue);
      expect(styledTileUrl(_mapbox, DealGoMapStyle.standard), _mapbox);
      expect(
        styledTileUrl(_mapbox, DealGoMapStyle.satellite),
        contains('/styles/v1/mapbox/satellite-streets-v12/tiles/256/'),
      );
      final dark = styledTileUrl(_mapbox, DealGoMapStyle.dark);
      expect(dark, contains('/mapbox/dark-v11/tiles/'));
      expect(dark, endsWith('@2x?access_token=k'));
    });

    test('a custom tile source keeps its single look', () {
      const osm = 'https://tile.example.com/{z}/{x}/{y}.png';
      expect(mapStylesSupported(osm), isFalse);
      expect(styledTileUrl(osm, DealGoMapStyle.dark), osm);
    });

    test('satellite credits Maxar once', () {
      const base = '© Mapbox © OpenStreetMap';
      expect(
        styledAttribution(base, _mapbox, DealGoMapStyle.satellite),
        '$base © Maxar',
      );
      expect(styledAttribution(base, _mapbox, DealGoMapStyle.dark), base);
    });

    test('the choice is remembered', () async {
      final controller = MapStyleController();
      await controller.select(DealGoMapStyle.dark);
      final restored = MapStyleController();
      await restored.restore();
      expect(restored.value, DealGoMapStyle.dark);
    });
  });

  group('reverse geocode cache', () {
    test('one lookup per ~11 m cell, shared while in flight', () async {
      final cache = ReverseGeocodeCache();
      var calls = 0;
      final gate = Completer<PlaceOption?>();
      Future<PlaceOption?> lookup() {
        calls++;
        return gate.future;
      }

      final a = cache.resolve(lat: 16.06801, lng: 108.22351, lookup: lookup);
      final b = cache.resolve(lat: 16.06804, lng: 108.22349, lookup: lookup);
      gate.complete(_place('Chợ Hàn', 16.068, 108.2235));
      expect((await a)?.name, 'Chợ Hàn');
      expect((await b)?.name, 'Chợ Hàn');
      await cache.resolve(lat: 16.068, lng: 108.2235, lookup: lookup);
      expect(calls, 1);
    });

    test('misses are remembered, failures are not', () async {
      final cache = ReverseGeocodeCache();
      var calls = 0;
      await cache.resolve(
        lat: 1,
        lng: 1,
        lookup: () async {
          calls++;
          return null;
        },
      );
      await cache.resolve(
        lat: 1,
        lng: 1,
        lookup: () async {
          calls++;
          return null;
        },
      );
      expect(calls, 1);
      await expectLater(
        cache.resolve(
          lat: 2,
          lng: 2,
          lookup: () async => throw StateError('x'),
        ),
        throwsStateError,
      );
      expect(cache.contains(2, 2), isFalse);
    });

    test('keeps only the newest cells', () async {
      final cache = ReverseGeocodeCache(capacity: 2);
      cache
        ..put(_place('a', 1, 1))
        ..put(_place('b', 2, 2))
        ..put(_place('c', 3, 3));
      expect(cache.length, 2);
      expect(cache.contains(1, 1), isFalse);
      expect(cache.contains(3, 3), isTrue);
    });
  });

  testWidgets('style switcher opens compact and applies to live maps', (
    tester,
  ) async {
    const port = TileMapPort(
      urlTemplate: _mapbox,
      attribution: '© Mapbox © OpenStreetMap',
    );
    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('vi'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(disableAnimations: true),
          child: child!,
        ),
        home: Scaffold(
          body: Stack(
            children: [
              SizedBox(
                width: 400,
                height: 600,
                child: TileMapPort(
                  urlTemplate: port.urlTemplate,
                  attribution: port.attribution,
                  tileProvider: _MemoryTiles(),
                ).buildMap(center: danangViewportCenter),
              ),
              Positioned(
                right: 16,
                top: 16,
                child: MapStyleSwitcher(available: mapStylesAvailable(port)),
              ),
            ],
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('map-style-panel')), findsNothing);
    await tester.tap(find.byKey(const Key('map-style-button')));
    await tester.pumpAndSettle();
    expect(find.text('Chuẩn'), findsOneWidget);
    expect(find.text('Vệ tinh'), findsOneWidget);
    expect(find.text('Tối'), findsOneWidget);

    await tester.tap(find.byKey(const Key('map-style-satellite')));
    await tester.pumpAndSettle();
    expect(mapStyle.value, DealGoMapStyle.satellite);
    expect(find.byKey(const Key('map-style-panel')), findsNothing);
    final layer = tester.widget<TileLayer>(find.byType(TileLayer));
    expect(layer.urlTemplate, contains('satellite-streets-v12'));
    expect(find.textContaining('Maxar'), findsOneWidget);
  });

  testWidgets('map side controls: layers on top, my-location below', (
    tester,
  ) async {
    var located = 0;
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        locale: const Locale('vi'),
        home: Scaffold(
          body: Align(
            alignment: Alignment.topRight,
            child: MapSideControls(
              stylesAvailable: true,
              onLocate: () => located++,
            ),
          ),
        ),
      ),
    );
    final layers = tester.getCenter(find.byKey(const Key('map-style-button')));
    final locate = tester.getCenter(find.byKey(const Key('map-locate')));
    expect(layers.dy, lessThan(locate.dy));
    expect((layers.dx - locate.dx).abs(), lessThan(1));
    await tester.tap(find.byKey(const Key('map-locate')));
    expect(located, 1);
  });

  testWidgets('no switcher for a single-look tile source', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(home: MapStyleSwitcher(available: false)),
    );
    expect(find.byKey(const Key('map-style-button')), findsNothing);
  });

  testWidgets('book tab has a back button and Android back returns home', (
    tester,
  ) async {
    await _openBook(tester);
    // Destination-first picker: close it to reach the map.
    await tester.tap(find.byKey(const Key('header-back')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('ride-map-back')), findsOneWidget);

    await tester.tap(find.byKey(const Key('ride-map-back')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('ride-map-back')), findsNothing);
    expect(navLabel('Đặt'), findsOneWidget);

    await tester.tap(navLabel('Đặt'));
    await tester.pumpAndSettle();
    // The picker may open again on re-entry; close it if so.
    if (find.byKey(const Key('header-back')).evaluate().isNotEmpty) {
      await tester.tap(find.byKey(const Key('header-back')));
      await tester.pumpAndSettle();
    }
    expect(find.byKey(const Key('ride-map-back')), findsOneWidget);
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('ride-map-back')), findsNothing);
    expect(navLabel('Đặt'), findsOneWidget);
  });

  testWidgets('pick on map: drag, one lookup after rest, confirm returns it', (
    tester,
  ) async {
    final places = _CountingPlaces();
    await _openBook(tester, places: places);
    expect(find.byKey(const Key('place-pick-on-map')), findsOneWidget);
    await tester.tap(find.byKey(const Key('place-pick-on-map')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('map-picker-back')), findsOneWidget);
    expect(find.byKey(const Key('map-picker-pin')), findsOneWidget);
    expect(find.text('Gần Chợ Hàn'), findsOneWidget);
    final first = places.reverses;

    // Several drags inside the rest window → a single lookup.
    final surface = find.byKey(const Key('picker-map-placeholder'));
    for (var i = 0; i < 4; i++) {
      await tester.drag(surface, const Offset(-60, 40));
      await tester.pump(const Duration(milliseconds: 100));
    }
    final confirm = find.byKey(const Key('map-picker-confirm'));
    expect(find.byKey(const Key('map-picker-address-loading')), findsOneWidget);
    await tester.pump(const Duration(milliseconds: 600));
    await tester.pumpAndSettle();
    expect(places.reverses, first + 1);

    await tester.tap(confirm);
    await tester.pumpAndSettle();
    // Back on the ride map with the pinned drop-off.
    expect(find.byKey(const Key('map-picker-confirm')), findsNothing);
    // The pinned drop-off opens the prices on its own.
    expect(find.byKey(const Key('ride-fare-back')), findsOneWidget);
    await tester.tap(find.byKey(const Key('ride-fare-back')));
    await tester.pumpAndSettle();
    expect(find.textContaining('Gần Chợ Hàn'), findsWidgets);
    expect(find.byKey(const Key('ride-map-back')), findsOneWidget);
  });

  testWidgets('pick on map: back closes search first, then the picker', (
    tester,
  ) async {
    await _openBook(tester);
    await tester.tap(find.byKey(const Key('place-pick-on-map')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('map-picker-search')));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const Key('map-picker-search-field')),
      'cầu rồng',
    );
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pumpAndSettle();
    expect(find.text('Cầu Rồng'), findsOneWidget);

    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('map-picker-search-field')), findsNothing);
    expect(find.byKey(const Key('map-picker-back')), findsOneWidget);

    await tester.tap(find.byKey(const Key('map-picker-back')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('map-picker-back')), findsNothing);
    expect(find.byKey(const Key('place-search-field')), findsOneWidget);
  });

  testWidgets('pick on map: a search hit moves the pin without a lookup', (
    tester,
  ) async {
    final places = _CountingPlaces();
    await _openBook(tester, places: places);
    await tester.tap(find.byKey(const Key('place-pick-on-map')));
    await tester.pumpAndSettle();
    final before = places.reverses;
    await tester.tap(find.byKey(const Key('map-picker-search')));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const Key('map-picker-search-field')),
      'cầu rồng',
    );
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('map-picker-result-0')));
    await tester.pump(const Duration(milliseconds: 600));
    await tester.pumpAndSettle();
    expect(places.reverses, before);
    expect(find.text('Cầu Rồng'), findsOneWidget);
  });

  testWidgets('pick on map: denied location explains and offers Settings', (
    tester,
  ) async {
    await _openBook(tester, denied: true);
    await tester.tap(find.byKey(const Key('place-pick-on-map')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('map-picker-locate')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('map-picker-denied')), findsOneWidget);
    expect(find.byKey(const Key('map-picker-settings')), findsOneWidget);
    // Still usable: confirm the fallback centre.
    final confirm = tester.widget<DealGoPrimaryButton>(
      find.byKey(const Key('map-picker-confirm')),
    );
    expect(confirm.enabled, isTrue);
  });
}
