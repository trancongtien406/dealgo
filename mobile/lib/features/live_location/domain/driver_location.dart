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

/// Server-chosen reporting cadence returned by `POST /v1/me/presence/location`
/// (DEC-PROD-031 rev 2026-10-24). ON_TRIP while the driver has an active job.
class DriverLocationPolicy {
  const DriverLocationPolicy({
    required this.mode,
    required this.interval,
    required this.minDistanceM,
    required this.maxSilence,
  });

  /// Client default until the first server reply. Mirrors the backend IDLE
  /// DRAFT defaults (15 s / 50 m / 60 s keep-alive).
  static const idle = DriverLocationPolicy(
    mode: 'IDLE',
    interval: Duration(seconds: 15),
    minDistanceM: 50,
    maxSilence: Duration(seconds: 60),
  );

  final String mode;
  final Duration interval;
  final double minDistanceM;
  final Duration maxSilence;
}

/// One location fix sent by the driver app.
class DriverLocationFix {
  const DriverLocationFix({
    required this.lat,
    required this.lng,
    this.heading,
    this.speedMps,
    this.accuracyM,
    this.recordedAt,
  });

  final double lat;
  final double lng;
  final double? heading;
  final double? speedMps;
  final double? accuracyM;
  final DateTime? recordedAt;

  /// Body for the POST; optional fields only when valid for the DTO bounds.
  Map<String, Object?> toJson() => {
    'lat': lat,
    'lng': lng,
    if (heading != null && heading! >= 0 && heading! <= 360) 'heading': heading,
    if (speedMps != null && speedMps! >= 0 && speedMps! <= 100)
      'speedMps': speedMps,
    if (accuracyM != null && accuracyM! >= 0 && accuracyM! <= 10000)
      'accuracyM': accuracyM,
    if (recordedAt != null) 'recordedAt': recordedAt!.toUtc().toIso8601String(),
  };
}

/// Server reply: whether the fix was kept, why not, and the cadence to use.
class DriverLocationReportResult {
  const DriverLocationReportResult({
    required this.accepted,
    this.reason,
    this.policy,
  });

  final bool accepted;
  final String? reason;
  final DriverLocationPolicy? policy;
}

/// Decodes `{ accepted, reason?, policy: { mode, intervalMs, minDistanceM, maxSilenceMs } }`.
/// Unknown / old server shapes → accepted with no policy (client keeps its own).
DriverLocationReportResult decodeDriverLocationReport(Object? data) {
  if (data is! Map) {
    return const DriverLocationReportResult(accepted: true);
  }
  final raw = data['policy'];
  DriverLocationPolicy? policy;
  if (raw is Map) {
    final interval = raw['intervalMs'];
    final distance = raw['minDistanceM'];
    final silence = raw['maxSilenceMs'];
    if (interval is num && distance is num && silence is num && interval > 0) {
      policy = DriverLocationPolicy(
        mode: '${raw['mode'] ?? 'IDLE'}',
        interval: Duration(milliseconds: interval.toInt()),
        minDistanceM: distance.toDouble(),
        maxSilence: Duration(milliseconds: silence.toInt()),
      );
    }
  }
  final reason = data['reason'];
  return DriverLocationReportResult(
    accepted: data['accepted'] != false,
    reason: reason is String ? reason : null,
    policy: policy,
  );
}

abstract interface class DriverLocationRepository {
  /// Driver heartbeat; changes only the stored position.
  Future<DriverLocationReportResult> report({
    required String accessToken,
    required DriverLocationFix fix,
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
