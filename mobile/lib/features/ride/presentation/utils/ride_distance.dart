import 'dart:math' as math;

import '../../../../core/maps/map_lat_lng.dart';
import '../../../../core/maps/route_geometry.dart';

/// Distance shown on the booking sheet once A and B are chosen.
///
/// [road] is true when the km came from Nest `GET /v1/rides/route` (the
/// configured routing provider); false means a straight-line estimate used
/// only because no road route was available — the UI marks it with `~` and
/// never draws a straight polyline for it.
class RideDistance {
  const RideDistance({required this.km, required this.road, this.minutes});

  final double km;
  final bool road;

  /// Drive time from the same route answer (null for the fallback).
  final int? minutes;

  static RideDistance from(RouteGeometry route, MapLatLng a, MapLatLng b) {
    final meters = route.distanceM;
    if (route.available && meters != null && meters > 0) {
      final sec = route.durationSec;
      return RideDistance(
        km: meters / 1000,
        road: true,
        minutes: sec != null && sec > 0 ? (sec / 60).ceil() : null,
      );
    }
    return RideDistance(km: haversineKm(a, b), road: false);
  }
}

/// Vietnamese km text: one decimal, comma separator (`3,2`), as on overview.
String formatRideKm(double km) => km.toStringAsFixed(1).replaceAll('.', ',');

/// Great-circle distance in km.
double haversineKm(MapLatLng a, MapLatLng b) {
  const r = 6371.0;
  double rad(double d) => d * math.pi / 180;
  final dLat = rad(b.lat - a.lat);
  final dLng = rad(b.lng - a.lng);
  final h =
      math.pow(math.sin(dLat / 2), 2) +
      math.cos(rad(a.lat)) *
          math.cos(rad(b.lat)) *
          math.pow(math.sin(dLng / 2), 2);
  return 2 * r * math.asin(math.min(1, math.sqrt(h.toDouble())));
}
