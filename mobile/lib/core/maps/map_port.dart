import 'package:flutter/widgets.dart';

import 'map_lat_lng.dart';

/// Map surface port. Real Google Maps / Mapbox adapters are key-fill later.
abstract interface class MapPort {
  /// Builds a map (or soft-fail placeholder) for the given center/markers.
  Widget buildMap({
    required MapLatLng center,
    List<MapLatLng> markers = const [],
    Key? key,
  });
}
