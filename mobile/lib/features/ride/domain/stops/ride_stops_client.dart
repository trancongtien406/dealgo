import '../entities/ride_models.dart';

/// Multi-stop commands (all admin feature-flagged on the server).
///
/// With the flags off [config] reports every service disabled and the UI
/// hides the stop controls, so rides stay single-destination.
abstract interface class RideStopsClient {
  /// `GET /v1/rides/multi-stop-config`.
  Future<MultiStopSettings> config({required String accessToken});

  /// `PUT /v1/rides/:id/stops` — customer replaces the stop list while
  /// NEGOTIATING; pending driver offers are dropped and the round restarts.
  Future<RideView> updateStops({
    required String accessToken,
    required String rideId,
    required List<RidePoint> stops,
    int? offeredFareVnd,
    int? routeVersion,
  });

  /// `POST /v1/rides/:id/stops/:seq/arrive` (assigned driver, IN_TRIP).
  Future<RideView> arriveStop({
    required String accessToken,
    required String rideId,
    required int seq,
  });

  /// `POST /v1/rides/:id/stops/:seq/depart` (assigned driver, IN_TRIP).
  Future<RideView> departStop({
    required String accessToken,
    required String rideId,
    required int seq,
  });
}
