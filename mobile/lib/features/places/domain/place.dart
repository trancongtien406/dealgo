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
  final n = cleanPlaceText(name);
  final a = cleanPlaceText(address);
  if (a.isEmpty || a == n) return n;
  if (n.isEmpty) return a;
  final fold = a.toLowerCase();
  if (fold == n.toLowerCase() || fold.startsWith('${n.toLowerCase()},')) {
    return a;
  }
  return '$n, $a';
}

/// Areas some providers return without diacritics (QA C6: "Hai Chau"): Đà Nẵng,
/// TP.HCM and Hà Nội districts + city names. Keep in sync with backend maps-port.ts.
const _unaccentedAreas = <String, String>{
  'ba dinh': 'Ba Đình',
  'bac tu liem': 'Bắc Từ Liêm',
  'binh chanh': 'Bình Chánh',
  'binh tan': 'Bình Tân',
  'binh thanh': 'Bình Thạnh',
  'cam le': 'Cẩm Lệ',
  'can gio': 'Cần Giờ',
  'cau giay': 'Cầu Giấy',
  'cu chi': 'Củ Chi',
  'da nang': 'Đà Nẵng',
  'da nang city': 'Đà Nẵng',
  'danang': 'Đà Nẵng',
  'district 1': 'Quận 1',
  'district 10': 'Quận 10',
  'district 11': 'Quận 11',
  'district 12': 'Quận 12',
  'district 2': 'Quận 2',
  'district 3': 'Quận 3',
  'district 4': 'Quận 4',
  'district 5': 'Quận 5',
  'district 6': 'Quận 6',
  'district 7': 'Quận 7',
  'district 8': 'Quận 8',
  'district 9': 'Quận 9',
  'dong anh': 'Đông Anh',
  'dong da': 'Đống Đa',
  'gia lam': 'Gia Lâm',
  'go vap': 'Gò Vấp',
  'ha dong': 'Hà Đông',
  'ha noi': 'Hà Nội',
  'hai ba trung': 'Hai Bà Trưng',
  'hai chau': 'Hải Châu',
  'hanoi': 'Hà Nội',
  'ho chi minh': 'Hồ Chí Minh',
  'ho chi minh city': 'Thành phố Hồ Chí Minh',
  'hoa vang': 'Hòa Vang',
  'hoan kiem': 'Hoàn Kiếm',
  'hoang mai': 'Hoàng Mai',
  'hoi an': 'Hội An',
  'hoi an dong': 'Hội An Đông',
  'hoi an tay': 'Hội An Tây',
  'hoc mon': 'Hóc Môn',
  'huyen binh chanh': 'Huyện Bình Chánh',
  'huyen can gio': 'Huyện Cần Giờ',
  'huyen cu chi': 'Huyện Củ Chi',
  'huyen dong anh': 'Huyện Đông Anh',
  'huyen gia lam': 'Huyện Gia Lâm',
  'huyen hoa vang': 'Huyện Hòa Vang',
  'huyen hoc mon': 'Huyện Hóc Môn',
  'huyen me linh': 'Huyện Mê Linh',
  'huyen nha be': 'Huyện Nhà Bè',
  'huyen soc son': 'Huyện Sóc Sơn',
  'huyen thanh tri': 'Huyện Thanh Trì',
  'lien chieu': 'Liên Chiểu',
  'long bien': 'Long Biên',
  'me linh': 'Mê Linh',
  'nam tu liem': 'Nam Từ Liêm',
  'ngu hanh son': 'Ngũ Hành Sơn',
  'nha be': 'Nhà Bè',
  'phu nhuan': 'Phú Nhuận',
  'quan 1': 'Quận 1',
  'quan 10': 'Quận 10',
  'quan 11': 'Quận 11',
  'quan 12': 'Quận 12',
  'quan 2': 'Quận 2',
  'quan 3': 'Quận 3',
  'quan 4': 'Quận 4',
  'quan 5': 'Quận 5',
  'quan 6': 'Quận 6',
  'quan 7': 'Quận 7',
  'quan 8': 'Quận 8',
  'quan 9': 'Quận 9',
  'quan ba dinh': 'Quận Ba Đình',
  'quan bac tu liem': 'Quận Bắc Từ Liêm',
  'quan binh tan': 'Quận Bình Tân',
  'quan binh thanh': 'Quận Bình Thạnh',
  'quan cam le': 'Quận Cẩm Lệ',
  'quan cau giay': 'Quận Cầu Giấy',
  'quan dong da': 'Quận Đống Đa',
  'quan go vap': 'Quận Gò Vấp',
  'quan ha dong': 'Quận Hà Đông',
  'quan hai ba trung': 'Quận Hai Bà Trưng',
  'quan hai chau': 'Quận Hải Châu',
  'quan hoan kiem': 'Quận Hoàn Kiếm',
  'quan hoang mai': 'Quận Hoàng Mai',
  'quan lien chieu': 'Quận Liên Chiểu',
  'quan long bien': 'Quận Long Biên',
  'quan nam tu liem': 'Quận Nam Từ Liêm',
  'quan ngu hanh son': 'Quận Ngũ Hành Sơn',
  'quan phu nhuan': 'Quận Phú Nhuận',
  'quan son tra': 'Quận Sơn Trà',
  'quan tan binh': 'Quận Tân Bình',
  'quan tan phu': 'Quận Tân Phú',
  'quan tay ho': 'Quận Tây Hồ',
  'quan thanh khe': 'Quận Thanh Khê',
  'quan thanh xuan': 'Quận Thanh Xuân',
  'sai gon': 'Sài Gòn',
  'saigon': 'Sài Gòn',
  'soc son': 'Sóc Sơn',
  'son tay': 'Sơn Tây',
  'son tra': 'Sơn Trà',
  'tan binh': 'Tân Bình',
  'tan phu': 'Tân Phú',
  'tay ho': 'Tây Hồ',
  'thanh khe': 'Thanh Khê',
  'thanh pho ha noi': 'Thành phố Hà Nội',
  'thanh pho ho chi minh': 'Thành phố Hồ Chí Minh',
  'thanh pho thu duc': 'Thành phố Thủ Đức',
  'thanh tri': 'Thanh Trì',
  'thanh xuan': 'Thanh Xuân',
  'thi xa son tay': 'Thị xã Sơn Tây',
  'thu duc': 'Thủ Đức',
  'tp ho chi minh': 'TP. Hồ Chí Minh',
  'tp. ho chi minh': 'TP. Hồ Chí Minh',
};

final _postal = RegExp(r'^\d{5,6}$');
final _postalEdge = RegExp(r'^\d{5,6}\s+|\s+\d{5,6}$');

/// Readable Vietnamese place text, for labels from any source (server,
/// device cache, rides saved by older builds): drops postal codes ("50200",
/// "Đà Nẵng 550000", "50200 Hai Chau"), the trailing "Việt Nam", restores
/// accents on Đà Nẵng / TP.HCM / Hà Nội districts, and removes a segment repeated back to back
/// ("3 Nguyễn Văn Linh, 3 Nguyễn Văn Linh, Hải Châu").
String cleanPlaceText(String text) {
  final out = <String>[];
  for (final raw in text.split(',')) {
    var part = raw.trim().replaceAll(_postalEdge, '').trim();
    if (part.isEmpty || _postal.hasMatch(part)) continue;
    if (RegExp(r'^(việt nam|vietnam)$', caseSensitive: false).hasMatch(part)) {
      continue;
    }
    part = _unaccentedAreas[part.toLowerCase()] ?? part;
    if (out.isNotEmpty && out.last.toLowerCase() == part.toLowerCase()) {
      continue;
    }
    out.add(part);
  }
  return out.join(', ');
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
