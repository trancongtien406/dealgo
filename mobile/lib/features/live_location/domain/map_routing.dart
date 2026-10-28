import '../../../core/maps/map_lat_lng.dart';
import '../../../core/maps/route_geometry.dart';

/// Road geometry lookup via Nest `ROUTING_PROVIDER` (Mapbox/OSRM).
abstract interface class MapRoutingRepository {
  Future<RouteGeometry> route({
    required String accessToken,
    required MapLatLng from,
    required MapLatLng to,

    /// Intermediate stops (multi-stop preview), in visiting order.
    List<MapLatLng> via = const [],
  });
}
