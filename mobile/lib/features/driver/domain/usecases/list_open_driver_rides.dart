import '../../../ride/domain/entities/ride_models.dart';
import '../repositories/driver_jobs_repository.dart';

class ListOpenDriverRides {
  const ListOpenDriverRides(this._repository);

  final DriverJobsRepository _repository;

  Future<List<OpenRide>> call(String accessToken) {
    return _repository.listOpenRides(accessToken);
  }
}

class DismissDriverRide {
  const DismissDriverRide(this._repository);

  final DriverJobsRepository _repository;

  Future<void> call({required String accessToken, required String rideId}) {
    return _repository.dismissRide(accessToken: accessToken, rideId: rideId);
  }
}
