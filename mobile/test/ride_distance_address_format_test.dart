import 'package:dealgo/core/maps/map_lat_lng.dart';
import 'package:dealgo/core/maps/route_geometry.dart';
import 'package:dealgo/features/places/domain/place.dart';
import 'package:dealgo/features/ride/presentation/utils/ride_distance.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('formatPlaceLabel', () {
    test('keeps the house number and does not repeat the name', () {
      expect(
        formatPlaceLabel(
          '3 Nguyễn Văn Linh',
          '3 Nguyễn Văn Linh, Hải Châu, Đà Nẵng',
        ),
        '3 Nguyễn Văn Linh, Hải Châu, Đà Nẵng',
      );
    });

    test('POI name joins its full street address', () {
      expect(
        formatPlaceLabel('Chợ Hàn', '119 Trần Phú, Hải Châu, Đà Nẵng'),
        'Chợ Hàn, 119 Trần Phú, Hải Châu, Đà Nẵng',
      );
    });

    test('empty or identical address gives just the name', () {
      expect(formatPlaceLabel('Trưng Nữ Vương', ''), 'Trưng Nữ Vương');
      expect(
        formatPlaceLabel('Trưng Nữ Vương', 'Trưng Nữ Vương'),
        'Trưng Nữ Vương',
      );
    });

    test('PlaceOption.label uses it', () {
      const place = PlaceOption(
        name: '3 Nguyễn Văn Linh',
        address: '3 Nguyễn Văn Linh, Hải Châu, Đà Nẵng',
        lat: 16.06,
        lng: 108.21,
        source: PlaceSource.search,
      );
      expect(place.label, '3 Nguyễn Văn Linh, Hải Châu, Đà Nẵng');
    });
  });

  group('ride distance', () {
    const a = MapLatLng(lat: 16.0544, lng: 108.2022);
    const b = MapLatLng(lat: 16.0439, lng: 108.1990);

    test('formats km with one decimal and a comma', () {
      expect(formatRideKm(3.24), '3,2');
      expect(formatRideKm(12), '12,0');
    });

    test('uses road distance when the route is available', () {
      const route = RouteGeometry(
        available: true,
        provider: 'mapbox',
        coords: [a, b],
        distanceM: 4250,
      );
      final d = RideDistance.from(route, a, b);
      expect(d.road, isTrue);
      expect(d.km, 4.25);
    });

    test('falls back to straight-line km without a route', () {
      final d = RideDistance.from(RouteGeometry.unavailable, a, b);
      expect(d.road, isFalse);
      expect(d.km, closeTo(1.21, 0.05));
    });
  });
}
