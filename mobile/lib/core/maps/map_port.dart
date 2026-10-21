import 'package:flutter/widgets.dart';

import 'map_lat_lng.dart';

/// Map surface port: live tiles (`TileMapPort`) or the illustrative placeholder.
abstract interface class MapPort {
  /// Builds a map (or soft-fail placeholder) for the given center/markers.
  /// [driver] is the assigned driver's live position (DEC-PROD-031), if known.
  Widget buildMap({
    required MapLatLng center,
    List<MapLatLng> markers = const [],
    MapLatLng? driver,
    Key? key,
  });
}
