import '../entities/ride_models.dart';
import '../params/cancel_ride_params.dart';
import '../repositories/ride_repository.dart';

class CancelRide {
  const CancelRide(this._repository);

  final RideRepository _repository;

  Future<RideView> call(CancelRideParams params) {
    return _repository.cancelRide(
      accessToken: params.accessToken,
      rideId: params.rideId,
    );
  }
}
