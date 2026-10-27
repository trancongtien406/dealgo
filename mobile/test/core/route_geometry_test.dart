import 'package:dealgo/core/maps/map_lat_lng.dart';
import 'package:dealgo/core/maps/route_geometry.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('parses Nest road geometry coords as lat,lng', () {
    final route = RouteGeometry.tryParse({
      'available': true,
      'provider': 'osrm',
      'coords': [
        [16.0544, 108.2022],
        [16.055, 108.21],
        [16.0592, 108.2435],
      ],
      'distanceM': 4200,
      'durationSec': 600,
    });
    expect(route, isNotNull);
    expect(route!.hasRoadPolyline, isTrue);
    expect(route.coords, hasLength(3));
    expect(route.coords.first.lat, 16.0544);
    expect(route.coords.first.lng, 108.2022);
    expect(
      route.polylineOr([
        const MapLatLng(lat: 0, lng: 0),
        const MapLatLng(lat: 1, lng: 1),
      ]),
      same(route.coords),
    );
  });

  test('unavailable route draws no line (never a straight A→B)', () {
    final route = RouteGeometry.tryParse({
      'available': false,
      'provider': 'none',
      'coords': <Object>[],
    });
    expect(route!.hasRoadPolyline, isFalse);
    final stops = [
      const MapLatLng(lat: 16.05, lng: 108.2),
      const MapLatLng(lat: 16.06, lng: 108.24),
    ];
    expect(route.polylineOr(stops), isEmpty);
  });

  test('multi-point Mapbox route keeps every coord for the polyline', () {
    final raw = [
      for (var i = 0; i < 12; i++)
        [16.05 + i * 0.001, 108.2 + (i.isEven ? 0.0 : 0.002)],
    ];
    final route = RouteGeometry.tryParse({
      'available': true,
      'provider': 'mapbox',
      'coords': raw,
    })!;
    final poly = route.polylineOr(const [
      MapLatLng(lat: 16.05, lng: 108.2),
      MapLatLng(lat: 16.061, lng: 108.202),
    ]);
    expect(poly.length, 12);
    expect(poly.first.lat, closeTo(16.05, 1e-9));
    expect(poly.last.lat, closeTo(16.061, 1e-9));
    expect(poly[1].lng, closeTo(108.202, 1e-9));
  });
}
