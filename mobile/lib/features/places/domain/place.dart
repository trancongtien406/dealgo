/// Where a place option came from; decides its icon and section.
enum PlaceSource { current, saved, recent, search, history }

/// A pickable location with real coordinates.
class PlaceOption {
  const PlaceOption({
    required this.name,
    required this.address,
    required this.lat,
    required this.lng,
    required this.source,
    this.historyId,
    this.approximate = false,
    this.distanceKm,
  });

  final String name;
  final String address;
  final double lat;
  final double lng;
  final PlaceSource source;

  /// Server id of a search-history row (only for [PlaceSource.history]).
  final String? historyId;

  /// The house number was put on the matched street by the server; the pin
  /// is the street, not the exact door.
  final bool approximate;

  /// Server-computed distance from the search bias point.
  final double? distanceKm;

  PlaceOption copyWith({PlaceSource? source, String? historyId}) => PlaceOption(
    name: name,
    address: address,
    lat: lat,
    lng: lng,
    source: source ?? this.source,
    historyId: historyId ?? this.historyId,
    approximate: approximate,
    distanceKm: distanceKm,
  );

  /// Label sent to the backend for a ride stop or drop-off (the API caps
  /// labels at [placeLabelMaxLength] characters).
  String get label {
    final full = formatPlaceLabel(name, address);
    return full.length > placeLabelMaxLength
        ? full.substring(0, placeLabelMaxLength)
        : full;
  }
}

/// One readable line for a place: `name, address`, without repeating the
/// name when the provider's address already starts with it (Google returns
/// name `3 Nguyễn Văn Linh` and address `3 Nguyễn Văn Linh, Hải Châu, …`).
/// The house number therefore survives instead of being duplicated or cut.
String formatPlaceLabel(String name, String address) {
  final n = name.trim();
  final a = address.trim();
  if (a.isEmpty || a == n) return n;
  if (n.isEmpty) return a;
  final fold = a.toLowerCase();
  if (fold == n.toLowerCase() || fold.startsWith('${n.toLowerCase()},')) {
    return a;
  }
  return '$n, $a';
}

/// Server limit for stop labels (`label` max 160 on rides and food orders).
const placeLabelMaxLength = 160;

class PlaceSearchResult {
  const PlaceSearchResult({
    required this.items,
    required this.available,
    this.googleAttribution = false,
  });

  final List<PlaceOption> items;

  /// Results came from Google Places: show the "Google Maps" attribution.
  final bool googleAttribution;

  /// False when the server has no maps provider; only saved/recent places work then.
  final bool available;
}

abstract interface class PlacesRepository {
  /// [nearLat]/[nearLng] bias results toward the user (server-side proximity).
  Future<PlaceSearchResult> search({
    required String accessToken,
    required String query,
    double? nearLat,
    double? nearLng,
  });

  /// Nearest address for a GPS fix; null when unknown.
  Future<PlaceOption?> reverse({
    required String accessToken,
    required double lat,
    required double lng,
  });

  /// Distinct drop-off points of the customer's latest rides, newest first.
  Future<List<PlaceOption>> recentDestinations({required String accessToken});

  /// The user's picked places (server-side, survives reinstall), newest first.
  Future<List<PlaceOption>> history({required String accessToken});

  /// Records a pick; the same place moves to the top. Returns the stored row.
  Future<PlaceOption?> recordHistory({
    required String accessToken,
    required PlaceOption place,
  });

  Future<void> deleteHistory({required String accessToken, required String id});

  Future<void> clearHistory({required String accessToken});
}

/// Server cap on a user's place history (newest kept).
const placeHistoryMax = 20;

/// Same place for history de-dup: folded name within ~110 m.
String placeDedupeKey(PlaceOption place) =>
    '${foldVietnamese(place.name)}@${place.lat.toStringAsFixed(3)},${place.lng.toStringAsFixed(3)}';

const _fromChars =
    'àáạảãâầấậẩẫăằắặẳẵèéẹẻẽêềếệểễìíịỉĩòóọỏõôồốộổỗơờớợởỡùúụủũưừứựửữỳýỵỷỹđ';
const _toChars =
    'aaaaaaaaaaaaaaaaaeeeeeeeeeeeiiiiiooooooooooooooooouuuuuuuuuuuyyyyyd';

/// Lower-case, Vietnamese diacritics removed, spaces collapsed.
String foldVietnamese(String value) {
  final lower = value.toLowerCase().trim();
  final out = StringBuffer();
  for (final rune in lower.runes) {
    final ch = String.fromCharCode(rune);
    final i = _fromChars.indexOf(ch);
    out.write(i < 0 ? ch : _toChars[i]);
  }
  return out.toString().replaceAll(RegExp(r'\s+'), ' ');
}
