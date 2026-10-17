import '../../../ride/domain/entities/ride_models.dart';
import '../../../ride/domain/params/submit_ride_offer_params.dart';
import '../repositories/driver_jobs_repository.dart';

class SubmitDriverRideOffer {
  const SubmitDriverRideOffer(this._repository);

  final DriverJobsRepository _repository;

  Future<RideView> call(SubmitRideOfferRequest request) {
    return _repository.submitOffer(request);
  }
}
