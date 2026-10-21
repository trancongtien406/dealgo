import '../config/app_env.dart';
import 'map_port.dart';
import 'placeholder_map_port.dart';
import 'tile_map_port.dart';

/// Selects the map adapter: live raster tiles when Mapbox/`MAP_TILE_URL` is
/// valid, otherwise the soft-fail placeholder.
MapPort createMapPort() {
  if (!useLiveMaps) {
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
