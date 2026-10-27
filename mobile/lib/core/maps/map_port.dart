import 'package:flutter/widgets.dart';

import 'map_lat_lng.dart';
import 'map_markers.dart';

/// Map surface port: live tiles (`TileMapPort`) or the illustrative placeholder.
abstract interface class MapPort {
  /// Builds a map (or soft-fail placeholder) for the given center/markers.
  /// [driver] is the assigned driver's live position (DEC-PROD-031), if known.
  /// [route] is an optional polyline (straight segments when no road geometry
  /// API is wired on mobile — same fallback Admin uses when ROUTING_PROVIDER=none).
  /// [fitPadding] insets the camera fit so overlays (sheet / stop chip) do not
  /// cover stop markers or the route line.
  /// [driverVehicle] picks the top-down vehicle (heading from movement/route).
  /// [firstMarkerIsPickup] false when only the dropoff remains (in-trip).
  /// [stopStyle] picks ride (person → flag) or food (store → home) pins.
  Widget buildMap({
    required MapLatLng center,
    List<MapLatLng> markers = const [],
    MapLatLng? driver,
    List<MapLatLng> route = const [],
    bool pulseRoute = false,
    EdgeInsets fitPadding = const EdgeInsets.all(32),
    MapVehicleKind driverVehicle = MapVehicleKind.motorbike,
    bool firstMarkerIsPickup = true,
    MapStopStyle stopStyle = MapStopStyle.ride,
    double? driverHeading,
    Duration? driverGlide,
    Key? key,
  });
}
