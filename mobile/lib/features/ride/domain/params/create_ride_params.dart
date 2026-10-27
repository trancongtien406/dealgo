import '../entities/ride_models.dart';

class CreateRideParams {
  const CreateRideParams({
    required this.accessToken,
    required this.idempotencyKey,
    required this.pickup,
    required this.dropoff,
    required this.offeredFareVnd,
    required this.vehicleClassCode,
  });

  final String accessToken;
  final String idempotencyKey;
  final RidePoint pickup;
  final RidePoint dropoff;
  final int offeredFareVnd;

  /// Required Ride class (MOTORBIKE | CAR_4 | CAR_7). No silent MOTORBIKE default (DG-DEC-VEH-001).
  final String vehicleClassCode;
}

/// Backward-compatible alias for existing tests and call sites.
typedef CreateRideRequest = CreateRideParams;
