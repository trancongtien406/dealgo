import '../entities/ride_models.dart';
import '../repositories/ride_repository.dart';

class ListOpenRides {
  const ListOpenRides(this._repository);

  final RideRepository _repository;

  Future<List<OpenRide>> call(String accessToken) {
    return _repository.listOpenRides(accessToken);
  }
}
