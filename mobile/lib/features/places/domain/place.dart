/// Where a place option came from; decides its icon and section.
enum PlaceSource { current, saved, recent, search }

/// A pickable location with real coordinates.
class PlaceOption {
  const PlaceOption({
    required this.name,
    required this.address,
    required this.lat,
    required this.lng,
    required this.source,
  });

  final String name;
  final String address;
  final double lat;
  final double lng;
  final PlaceSource source;

  /// Label sent to the backend for a ride stop or drop-off (the API caps
  /// labels at [placeLabelMaxLength] characters).
  String get label {
    final full = address.isEmpty || address == name ? name : '$name, $address';
    return full.length > placeLabelMaxLength
        ? full.substring(0, placeLabelMaxLength)
        : full;
  }
}

/// Server limit for stop labels (`label` max 160 on rides and food orders).
const placeLabelMaxLength = 160;

class PlaceSearchResult {
  const PlaceSearchResult({required this.items, required this.available});

  final List<PlaceOption> items;

  /// False when the server has no maps provider; only saved/recent places work then.
  final bool available;
}

abstract interface class PlacesRepository {
  Future<PlaceSearchResult> search({
    required String accessToken,
    required String query,
  });

  /// Nearest address for a GPS fix; null when unknown.
  Future<PlaceOption?> reverse({
    required String accessToken,
    required double lat,
    required double lng,
  });

  /// Distinct drop-off points of the customer's latest rides, newest first.
  Future<List<PlaceOption>> recentDestinations({required String accessToken});
}
