import 'package:dealgo/core/maps/live_route.dart';
import 'package:dealgo/core/maps/map_lat_lng.dart';
import 'package:dealgo/core/maps/route_geometry.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const a = MapLatLng(lat: 16.0544, lng: 108.2022);
  const b = MapLatLng(lat: 16.0678, lng: 108.2208);

  test('mapDistanceMeters is ~2.5km for sample Danang points', () {
    final m = mapDistanceMeters(a, b);
    expect(m, greaterThan(2000));
    expect(m, lessThan(3500));
  });

  test('shouldRerouteLive triggers on first fix, move, or interval', () {
    final t0 = DateTime.utc(2026, 10, 23, 12);
    expect(
      shouldRerouteLive(lastOrigin: null, nextOrigin: a, lastAt: null, now: t0),
      isTrue,
    );
    expect(
      shouldRerouteLive(
        lastOrigin: a,
        nextOrigin: a,
        lastAt: t0,
        now: t0.add(const Duration(seconds: 5)),
      ),
      isFalse,
    );
    expect(
      shouldRerouteLive(
        lastOrigin: a,
        nextOrigin: b,
        lastAt: t0,
        now: t0.add(const Duration(seconds: 5)),
      ),
      isTrue,
    );
    expect(
      shouldRerouteLive(
        lastOrigin: a,
        nextOrigin: a,
        lastAt: t0,
        now: t0.add(const Duration(seconds: 25)),
      ),
      isTrue,
    );
  });

  test('resolveLivePolyline prefers Nest road coords', () {
    final road = RouteGeometry(
      available: true,
      provider: 'mapbox',
      coords: const [a, b],
    );
    final driver = const MapLatLng(lat: 16.06, lng: 108.21);
    expect(
      resolveLivePolyline(live: road, driver: driver, target: b),
      road.coords,
    );
    expect(
      resolveLivePolyline(
        live: RouteGeometry.unavailable,
        driver: driver,
        target: b,
      ),
      isEmpty,
    );
    final last = [a, const MapLatLng(lat: 16.055, lng: 108.21), b];
    expect(
      resolveLivePolyline(
        live: RouteGeometry.unavailable,
        driver: driver,
        target: b,
        fallback: last,
      ),
      last,
    );
  });

  test('lerpMapLatLng midpoints', () {
    final mid = lerpMapLatLng(a, b, 0.5);
    expect(mid.lat, closeTo((a.lat + b.lat) / 2, 1e-9));
    expect(mid.lng, closeTo((a.lng + b.lng) / 2, 1e-9));
  });
}
