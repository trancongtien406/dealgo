const useMockData = bool.fromEnvironment('USE_MOCK_DATA', defaultValue: false);

/// Optional Google Maps / Mapbox client key. Empty → placeholder map (fail soft).
const mapsApiKey = String.fromEnvironment('MAPS_API_KEY', defaultValue: '');

/// When true and [mapsApiKey] is set, prefer a real map SDK adapter (key-fill later).
bool get useLiveMaps => !useMockData && mapsApiKey.isNotEmpty;
