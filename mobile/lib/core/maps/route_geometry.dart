import 'map_lat_lng.dart';

/// Road geometry from Nest (`route` on ride/food/quote, or `GET /v1/rides/route`).
///
/// When [available] is false the UI draws NO line (markers only) — a straight
/// pickup→dropoff segment must never be shown as if it were the road path.
class RouteGeometry {
  const RouteGeometry({
    required this.available,
    required this.provider,
    required this.coords,
    this.distanceM,
    this.durationSec,
  });

  static const unavailable = RouteGeometry(
    available: false,
    provider: 'none',
    coords: [],
  );

  final bool available;
  final String provider;
  final List<MapLatLng> coords;
  final int? distanceM;
  final int? durationSec;

  bool get hasRoadPolyline => available && coords.length >= 2;

  /// Road coords when available; otherwise empty (no fake straight line).
  /// [stops] is kept for call-site compatibility and intentionally ignored.
  List<MapLatLng> polylineOr(List<MapLatLng> stops) =>
      hasRoadPolyline ? coords : const [];

  static RouteGeometry? tryParse(Object? raw) {
    if (raw is! Map) {
      return null;
    }
    final map = Map<String, Object?>.from(raw);
    final available = map['available'] == true;
    final provider = map['provider'] is String
        ? map['provider'] as String
        : 'none';
    final coords = <MapLatLng>[];
    final rawCoords = map['coords'];
    if (rawCoords is List) {
      for (final point in rawCoords) {
        if (point is! List || point.length < 2) {
          continue;
        }
        final lat = point[0];
        final lng = point[1];
        if (lat is! num || lng is! num) {
          continue;
        }
        coords.add(MapLatLng(lat: lat.toDouble(), lng: lng.toDouble()));
      }
    }
    int? asInt(Object? v) => v is num ? v.round() : null;
    if (!available || coords.length < 2) {
      return RouteGeometry(
        available: false,
        provider: provider,
        coords: const [],
        distanceM: asInt(map['distanceM']),
        durationSec: asInt(map['durationSec']),
      );
    }
    return RouteGeometry(
      available: true,
      provider: provider,
      coords: List.unmodifiable(coords),
      distanceM: asInt(map['distanceM']),
      durationSec: asInt(map['durationSec']),
    );
  }
}
