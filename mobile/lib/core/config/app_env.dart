import 'package:flutter/foundation.dart';

const useMockData = bool.fromEnvironment('USE_MOCK_DATA', defaultValue: false);

/// Optional map provider key, substituted into `{key}` of [mapTileUrl].
const mapsApiKey = String.fromEnvironment('MAPS_API_KEY', defaultValue: '');

/// Raster XYZ tile template for the live map, e.g.
/// `https://tiles.example.com/{z}/{x}/{y}.png?key={key}`. Empty with a key →
/// Mapbox Streets (DEC-PROD-030). Empty without a key → placeholder.
const mapTileUrl = String.fromEnvironment('MAP_TILE_URL', defaultValue: '');

/// Attribution text the tile provider requires (shown on the map).
const mapAttribution = String.fromEnvironment(
  'MAP_ATTRIBUTION',
  defaultValue: '',
);

/// Mapbox public token set in Admin › Bản đồ, resolved by `MapsClientConfig`
/// under the native splash (cache first, network on first launch) and kept
/// fresh in the background. Wins over [mapsApiKey] for Mapbox tiles; empty →
/// the build-time key. Map pages rebuild when it changes.
final ValueNotifier<String> adminMapboxTokenListenable = ValueNotifier('');

String get adminMapboxToken => adminMapboxTokenListenable.value;
set adminMapboxToken(String value) => adminMapboxTokenListenable.value = value;

/// Key filled into `{key}`: the Admin Mapbox token for Mapbox tiles, else
/// `MAPS_API_KEY`.
String get effectiveMapsApiKey {
  final custom = mapTileUrl.trim();
  final mapboxTiles = custom.isEmpty || custom.contains('api.mapbox.com');
  if (mapboxTiles && adminMapboxToken.isNotEmpty) {
    return adminMapboxToken;
  }
  return mapsApiKey;
}

/// Default Mapbox Streets raster XYZ template when only a key is set.
/// Matches Admin web (`256` + `@2x`) for crisp tiles on phone screens.
const mapboxStreetsTileUrl =
    'https://api.mapbox.com/styles/v1/mapbox/streets-v12/tiles/256/{z}/{x}/{y}@2x?access_token={key}';

const mapboxAttributionDefault = '© Mapbox © OpenStreetMap';

/// Effective tile template after defaults (Mapbox when key-only).
String get effectiveMapTileUrl {
  final trimmed = mapTileUrl.trim();
  if (trimmed.isNotEmpty) {
    return trimmed;
  }
  if (effectiveMapsApiKey.trim().isNotEmpty) {
    return mapboxStreetsTileUrl;
  }
  return '';
}

/// Effective attribution after Mapbox default.
String get effectiveMapAttribution {
  final trimmed = mapAttribution.trim();
  if (trimmed.isNotEmpty) {
    return trimmed;
  }
  if (effectiveMapTileUrl.contains('api.mapbox.com')) {
    return mapboxAttributionDefault;
  }
  return '';
}

/// True when a usable live tile source is configured.
bool get useLiveMaps =>
    !useMockData &&
    resolveTileUrlTemplate(effectiveMapTileUrl, apiKey: effectiveMapsApiKey) !=
        null;

/// Validates a tile template and fills `{key}`; null when unusable (missing
/// `{z}/{x}/{y}`, not https, or `{key}` required but no key given).
String? resolveTileUrlTemplate(String template, {required String apiKey}) {
  final trimmed = template.trim();
  if (trimmed.isEmpty || !trimmed.startsWith('https://')) {
    return null;
  }
  for (final token in const ['{z}', '{x}', '{y}']) {
    if (!trimmed.contains(token)) {
      return null;
    }
  }
  if (trimmed.contains('{key}')) {
    if (apiKey.isEmpty) {
      return null;
    }
    return trimmed.replaceAll('{key}', Uri.encodeComponent(apiKey));
  }
  return trimmed;
}

/// Single web domain for universal/app links and passkeys (DEC-PROD-058). Must
/// match backend WEBAUTHN_RP_ID, the iOS associated domains and the Android
/// intent-filter host (`dealgoAppLinkHost` in android/gradle.properties).
const appLinkHost = String.fromEnvironment(
  'APP_LINK_HOST',
  defaultValue: 'dealgo.laptrinhapp.com',
);

/// Flutter flavor from `--flavor` or the Xcode `dev` / `prod` scheme; empty when
/// the build has none.
const flutterAppFlavor = String.fromEnvironment('FLUTTER_APP_FLAVOR');

/// `dev` / `prod` for telemetry: the flavor name, and prod for unflavored
/// release builds.
const appEnvironment = String.fromEnvironment(
  'SENTRY_ENVIRONMENT',
  defaultValue:
      flutterAppFlavor == 'prod' || (flutterAppFlavor == '' && kReleaseMode)
      ? 'prod'
      : 'dev',
);

/// Path prefix the app claims on [appLinkHost]; the rest stays on the website.
const appLinkPathPrefix = '/app';
