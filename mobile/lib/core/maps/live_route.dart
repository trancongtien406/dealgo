import 'dart:math' as math;

import 'map_lat_lng.dart';
import 'route_geometry.dart';

/// How the tracking map should treat the polyline while a driver is live.
enum LiveRoutePhase {
  /// Keep the booked A→B (or store→dropoff) geometry; driver is a marker only.
  staticStops,

  /// Re-route from the live driver fix toward pickup / store.
  toPickup,

  /// Re-route from the live driver fix toward dropoff (in-trip / after pickup).
  toDropoff,
}

/// Haversine distance in meters between two WGS84 points.
double mapDistanceMeters(MapLatLng a, MapLatLng b) {
  const earth = 6371000.0;
  final dLat = _rad(b.lat - a.lat);
  final dLng = _rad(b.lng - a.lng);
  final lat1 = _rad(a.lat);
  final lat2 = _rad(b.lat);
  final h =
      math.sin(dLat / 2) * math.sin(dLat / 2) +
      math.cos(lat1) * math.cos(lat2) * math.sin(dLng / 2) * math.sin(dLng / 2);
  return 2 * earth * math.asin(math.min(1.0, math.sqrt(h)));
}

double _rad(double deg) => deg * math.pi / 180.0;

/// Whether we should call Nest `GET /v1/rides/route` again for a live remaining path.
bool shouldRerouteLive({
  required MapLatLng? lastOrigin,
  required MapLatLng nextOrigin,
  required DateTime? lastAt,
  required DateTime now,
  double minMoveMeters = 40,
  Duration minInterval = const Duration(seconds: 20),
}) {
  if (lastOrigin == null || lastAt == null) {
    return true;
  }
  if (now.difference(lastAt) >= minInterval) {
    return true;
  }
  return mapDistanceMeters(lastOrigin, nextOrigin) >= minMoveMeters;
}

/// Prefer Nest road coords; otherwise the last road polyline; else empty.
/// Never fabricates a straight driver→target segment.
List<MapLatLng> resolveLivePolyline({
  required RouteGeometry? live,
  required MapLatLng driver,
  required MapLatLng target,
  List<MapLatLng> fallback = const [],
}) {
  if (live != null && live.hasRoadPolyline) {
    return live.coords;
  }
  if (fallback.length >= 2) {
    return fallback;
  }
  return const [];
}

MapLatLng lerpMapLatLng(MapLatLng a, MapLatLng b, double t) {
  final clamped = t.clamp(0.0, 1.0);
  return MapLatLng(
    lat: a.lat + (b.lat - a.lat) * clamped,
    lng: a.lng + (b.lng - a.lng) * clamped,
  );
}
