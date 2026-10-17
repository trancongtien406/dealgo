import '../config/app_env.dart';
import 'map_port.dart';
import 'placeholder_map_port.dart';

/// Selects map adapter. Live Google/Mapbox SDK is key-fill later — fail soft.
MapPort createMapPort() {
  if (!useLiveMaps) {
    return const PlaceholderMapPort();
  }
  // MAPS_API_KEY present but google_maps_flutter / mapbox not wired yet.
  return const PlaceholderMapPort();
}
