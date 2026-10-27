import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Base map look the user can switch between on any live map.
enum DealGoMapStyle { standard, satellite, dark }

/// Mapbox style ids for each look (raster Static Tiles API, same account and
/// key as the default Streets template).
const mapboxStyleIds = <DealGoMapStyle, String>{
  DealGoMapStyle.standard: 'streets-v12',
  DealGoMapStyle.satellite: 'satellite-streets-v12',
  DealGoMapStyle.dark: 'dark-v11',
};

final _mapboxStyleSegment = RegExp(
  r'/styles/v1/mapbox/([A-Za-z0-9._-]+)/tiles/',
);

/// True when [template] is a Mapbox style tile URL, so the other looks can be
/// derived from it. A custom `MAP_TILE_URL` keeps its single look.
bool mapStylesSupported(String template) =>
    _mapboxStyleSegment.hasMatch(template);

/// [template] with its Mapbox style id swapped for [style]; unchanged when the
/// template is not a Mapbox style URL or [style] is standard.
String styledTileUrl(String template, DealGoMapStyle style) {
  if (style == DealGoMapStyle.standard || !mapStylesSupported(template)) {
    return template;
  }
  return template.replaceFirstMapped(
    _mapboxStyleSegment,
    (_) => '/styles/v1/mapbox/${mapboxStyleIds[style]}/tiles/',
  );
}

/// Attribution for [style]: Mapbox satellite imagery also credits Maxar.
String styledAttribution(
  String attribution,
  String template,
  DealGoMapStyle style,
) {
  if (style != DealGoMapStyle.satellite ||
      !mapStylesSupported(template) ||
      attribution.isEmpty ||
      attribution.contains('Maxar')) {
    return attribution;
  }
  return '$attribution © Maxar';
}

/// App-wide selected map look, remembered across launches.
class MapStyleController extends ValueNotifier<DealGoMapStyle> {
  MapStyleController() : super(DealGoMapStyle.standard);

  static const prefsKey = 'map_style';
  var _restored = false;

  /// Loads the saved look once; later calls are no-ops.
  Future<void> restore() async {
    if (_restored) {
      return;
    }
    _restored = true;
    try {
      final prefs = await SharedPreferences.getInstance();
      final saved = prefs.getString(prefsKey);
      for (final style in DealGoMapStyle.values) {
        if (style.name == saved) {
          value = style;
        }
      }
    } catch (_) {
      // No storage (tests, first boot): keep the default look.
    }
  }

  Future<void> select(DealGoMapStyle style) async {
    _restored = true;
    if (value == style) {
      return;
    }
    value = style;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(prefsKey, style.name);
    } catch (_) {}
  }
}

/// Shared by every map so a switch applies everywhere at once.
final mapStyle = MapStyleController();
