/// DEC-PROD-031: live driver position shared with the customer of an active job.
enum TrackedJob { ride, food }

class DriverLiveLocation {
  const DriverLiveLocation({
    required this.lat,
    required this.lng,
    required this.at,
  });

  final double lat;
  final double lng;

  /// When the driver app reported this position.
  final DateTime at;
}

abstract interface class DriverLocationRepository {
  /// Driver heartbeat; changes only the stored position.
  Future<void> report({
    required String accessToken,
    required double lat,
    required double lng,
  });

  /// The assigned driver's fresh position, or null when unknown/stale.
  Future<DriverLiveLocation?> latest({
    required String accessToken,
    required TrackedJob job,
    required String id,
  });
}

/// Decodes `{ location: { lat, lng, at } | null }`.
DriverLiveLocation? decodeDriverLocation(Map<String, Object?> data) {
  final raw = data['location'];
  if (raw is! Map) {
    return null;
  }
  final lat = raw['lat'];
  final lng = raw['lng'];
  final at = DateTime.tryParse('${raw['at']}');
  if (lat is! num || lng is! num || at == null) {
    return null;
  }
  return DriverLiveLocation(lat: lat.toDouble(), lng: lng.toDouble(), at: at);
}
