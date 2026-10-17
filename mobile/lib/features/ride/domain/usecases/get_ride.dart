import '../entities/ride_models.dart';
import '../params/get_ride_params.dart';
import '../repositories/ride_repository.dart';

class GetRide {
  const GetRide(this._repository);

  final RideRepository _repository;

  Future<RideView> call(GetRideParams params) {
    return _repository.getRide(
      accessToken: params.accessToken,
      rideId: params.rideId,
    );
  }
}
