import '../entities/ride_models.dart';

class CreateRideParams {
  const CreateRideParams({
    required this.accessToken,
    required this.idempotencyKey,
    required this.pickup,
    required this.dropoff,
    required this.offeredFareVnd,
  });

  final String accessToken;
  final String idempotencyKey;
  final RidePoint pickup;
  final RidePoint dropoff;
  final int offeredFareVnd;
}

/// Backward-compatible alias for existing tests and call sites.
typedef CreateRideRequest = CreateRideParams;
