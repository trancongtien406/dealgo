import 'package:dealgo/features/places/data/place_history_cache.dart';
import 'package:dealgo/features/places/data/places_remote_datasource.dart';
import 'package:dealgo/features/places/data/reverse_geocode_cache.dart';
import 'package:dealgo/features/places/domain/place.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'support/auth_test_harness.dart';
import 'support/fake_identity_client.dart';
import 'support/fake_location.dart';

const _han = PlaceOption(
  name: 'Chợ Hàn',
  address: '119 Trần Phú, Hải Châu, Đà Nẵng',
  lat: 16.068,
  lng: 108.2235,
  source: PlaceSource.history,
);

const _khe = PlaceOption(
  name: 'Biển Mỹ Khê',
  address: 'Võ Nguyên Giáp, Sơn Trà, Đà Nẵng',
  lat: 16.0617,
  lng: 108.2476,
  source: PlaceSource.history,
);

const _street = PlaceOption(
  name: '12 Nguyễn Hoàng',
  address: 'Hòa Cường, Hải Châu, Đà Nẵng',
  lat: 16.0603,
  lng: 108.2101,
  source: PlaceSource.search,
  approximate: true,
  distanceKm: 1.1,
);

/// Records the bias point of every search.
class _Places extends FakePlacesRemoteDataSource {
  _Places({super.history, super.recent, super.googleAttribution})
    : super(catalog: [_street, ...FakePlacesRemoteDataSource.sampleCatalog]);

  final searches = <(double?, double?)>[];

  @override
  Future<PlaceSearchResult> search({
    required String accessToken,
    required String query,
    double? nearLat,
    double? nearLng,
  }) {
    searches.add((nearLat, nearLng));
    return super.search(
      accessToken: accessToken,
      query: query,
      nearLat: nearLat,
      nearLng: nearLng,
    );
  }
}

Future<void> _openPicker(WidgetTester tester, _Places places) async {
  await tester.binding.setSurfaceSize(const Size(400, 1400));
  addTearDown(() => tester.binding.setSurfaceSize(null));
  await pumpSignedIn(
    tester,
    profile: customerProfile,
    places: places,
    locationOverride: FakeLocationService(),
  );
  // "Đặt" opens the drop-off picker straight away (destination first).
  await tester.tap(navLabel('Đặt'));
  await tester.pumpAndSettle();
  expect(find.text('Bạn muốn đi đâu?'), findsOneWidget);
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    reverseGeocodeCache.clear();
  });
  tearDown(PlaceHistoryCache.clear);

  group('decoding', () {
    test('search rows keep distance and the approximate flag', () {
      final result = decodePlaceSearch({
        'available': true,
        'items': [
          {
            'name': '12 Nguyễn Hoàng',
            'address': 'Hòa Cường',
            'lat': 16.06,
            'lng': 108.21,
            'approximate': true,
            'distanceKm': 1.14,
          },
          {'name': 'Chợ Hàn', 'lat': 16.068, 'lng': 108.2235},
        ],
      });
      expect(result.items.first.approximate, isTrue);
      expect(result.items.first.distanceKm, 1.14);
      expect(result.items.last.approximate, isFalse);
      expect(result.items.last.distanceKm, isNull);
    });

    test('Google results carry the attribution flag', () {
      expect(decodePlaceSearch({'items': []}).googleAttribution, isFalse);
      expect(
        decodePlaceSearch({'items': [], 'attribution': 'google'})
            .googleAttribution,
        isTrue,
      );
    });

    test('history rows need an id', () {
      final rows = decodePlaceHistory({
        'items': [
          {'id': 'a', 'name': 'Chợ Hàn', 'lat': 16.068, 'lng': 108.2235},
          {'name': 'no id', 'lat': 1, 'lng': 1},
        ],
      });
      expect(rows.single.historyId, 'a');
      expect(rows.single.source, PlaceSource.history);
    });

    test('diacritics-insensitive de-dup key', () {
      expect(foldVietnamese('  Đường  Nguyễn Hoàng '), 'duong nguyen hoang');
      expect(
        placeDedupeKey(_han),
        placeDedupeKey(
          const PlaceOption(
            name: 'cho han',
            address: '',
            lat: 16.0681,
            lng: 108.2236,
            source: PlaceSource.search,
          ),
        ),
      );
    });
  });

  test('the device cache round-trips and keeps 20', () async {
    await PlaceHistoryCache.save([
      for (var i = 0; i < 25; i++)
        PlaceOption(
          name: 'Nơi $i',
          address: '',
          lat: 16 + i / 100,
          lng: 108,
          source: PlaceSource.history,
          historyId: 'id$i',
        ),
    ]);
    final rows = await PlaceHistoryCache.load();
    expect(rows, hasLength(placeHistoryMax));
    expect(rows.first.historyId, 'id0');
  });

  testWidgets('history is listed with ride recents, minus duplicates', (
    tester,
  ) async {
    final places = _Places(
      history: [_han, _khe],
      recent: [
        _han.copyWith(source: PlaceSource.recent),
        FakePlacesRemoteDataSource.sampleRecent.single,
      ],
    );
    await _openPicker(tester, places);
    expect(find.text('Gần đây'), findsOneWidget);
    expect(find.byKey(const Key('place-history-0')), findsOneWidget);
    expect(find.byKey(const Key('place-history-1')), findsOneWidget);
    // Chợ Hàn appears once (history), the airport once (ride recent).
    expect(find.text('Chợ Hàn'), findsOneWidget);
    expect(find.text('Sân bay Quốc tế Đà Nẵng'), findsOneWidget);
  });

  testWidgets('delete one entry, then clear all after confirming', (
    tester,
  ) async {
    final places = _Places(history: [_han, _khe]);
    await _openPicker(tester, places);

    await tester.tap(find.byKey(const Key('place-history-delete-0')));
    await tester.pumpAndSettle();
    expect(find.text('Chợ Hàn'), findsNothing);
    expect(places.historyRows.map((r) => r.name), ['Biển Mỹ Khê']);

    await tester.tap(find.byKey(const Key('place-history-clear')));
    await tester.pumpAndSettle();
    expect(find.text('Xóa lịch sử tìm kiếm?'), findsOneWidget);
    await tester.tap(find.byKey(const Key('place-history-clear-confirm')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('place-history-0')), findsNothing);
    expect(places.historyRows, isEmpty);
    expect(await PlaceHistoryCache.load(), isEmpty);
  });

  testWidgets('results show distance and the approximate hint; picking '
      'records history', (tester) async {
    final places = _Places();
    await _openPicker(tester, places);
    await tester.enterText(
      find.byKey(const Key('place-search-field')),
      'nguyễn hoàng',
    );
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pumpAndSettle();

    expect(find.text('12 Nguyễn Hoàng'), findsOneWidget);
    expect(find.text('1,1 km'), findsOneWidget);
    expect(find.textContaining('Số nhà ước tính'), findsOneWidget);
    // Biased to the device fix (fake location), not the null island.
    expect(places.searches.last.$1, isNotNull);

    await tester.tap(find.byKey(const Key('place-result-0')));
    await tester.pumpAndSettle();
    expect(places.historyRows.single.name, '12 Nguyễn Hoàng');
    expect((await PlaceHistoryCache.load()).single.name, '12 Nguyễn Hoàng');
  });

  testWidgets('the map picker lists history while its search is empty', (
    tester,
  ) async {
    final places = _Places(history: [_han]);
    await _openPicker(tester, places);
    await tester.tap(find.byKey(const Key('place-pick-on-map')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('map-picker-search')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('map-picker-history-0')), findsOneWidget);

    await tester.enterText(
      find.byKey(const Key('map-picker-search-field')),
      'cầu rồng',
    );
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('map-picker-history-0')), findsNothing);
    expect(find.byKey(const Key('map-picker-result-0')), findsOneWidget);
  });

  for (final google in [false, true]) {
    testWidgets('"Google Maps" attribution only for Google results ($google)', (
      tester,
    ) async {
      await _openPicker(tester, _Places(googleAttribution: google));
      await tester.enterText(
        find.byKey(const Key('place-search-field')),
        'chợ',
      );
      await tester.pump(const Duration(milliseconds: 400));
      await tester.pumpAndSettle();
      expect(find.text('Chợ Hàn'), findsOneWidget);
      expect(
        find.byKey(const Key('place-google-attribution')),
        google ? findsOneWidget : findsNothing,
      );
    });
  }
}
