import '../../../ride/domain/entities/ride_models.dart';
import '../../../ride/domain/params/ride_driver_action.dart';
import '../repositories/driver_jobs_repository.dart';

/// Moves an assigned ride along the backend trip state machine.
class AdvanceDriverRide {
  const AdvanceDriverRide(this._repository);

  final DriverJobsRepository _repository;

  Future<RideView> call({
    required String accessToken,
    required String rideId,
    required RideDriverAction action,
    String? pickupCode,
  }) {
    return _repository.advanceRide(
      accessToken: accessToken,
      rideId: rideId,
      action: action,
      pickupCode: pickupCode,
    );
  }
}
