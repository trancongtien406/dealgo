import 'package:flutter/foundation.dart';

import '../config/app_env.dart';
import 'map_port.dart';
import 'placeholder_map_port.dart';
import 'tile_map_port.dart';

/// Selects the map adapter: live raster tiles when Mapbox/`MAP_TILE_URL` is
/// valid, otherwise the soft-fail placeholder.
var _warned = false;

MapPort createMapPort() {
  if (!useLiveMaps) {
    // Make the illustrative map impossible to miss in dev logs: it draws a
    // fixed curve, not the real road route.
    if (!_warned) {
      _warned = true;
      debugPrint(
        'maps: PLACEHOLDER map (no MAPS_API_KEY / MAP_TILE_URL dart-define, '
        'or USE_MOCK_DATA) - routes are not drawn on real roads',
      );
    }
    return const PlaceholderMapPort();
  }
  return TileMapPort(
    urlTemplate: resolveTileUrlTemplate(
      effectiveMapTileUrl,
      apiKey: mapsApiKey,
    )!,
    attribution: effectiveMapAttribution,
  );
}
