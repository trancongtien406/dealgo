import '../../../ride/domain/entities/ride_models.dart';
import '../repositories/driver_jobs_repository.dart';

class ListOpenDriverRides {
  const ListOpenDriverRides(this._repository);

  final DriverJobsRepository _repository;

  Future<List<OpenRide>> call(String accessToken) {
    return _repository.listOpenRides(accessToken);
  }
}
