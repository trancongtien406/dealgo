import '../entities/ride_models.dart';
import '../params/create_ride_params.dart';
import '../repositories/ride_repository.dart';

class CreateRide {
  const CreateRide(this._repository);

  final RideRepository _repository;

  Future<RideView> call(CreateRideParams params) {
    return _repository.createRide(params);
  }
}
