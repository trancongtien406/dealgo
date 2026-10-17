import '../entities/ride_models.dart';
import '../params/submit_ride_offer_params.dart';
import '../repositories/ride_repository.dart';

class SubmitRideOffer {
  const SubmitRideOffer(this._repository);

  final RideRepository _repository;

  Future<RideView> call(SubmitRideOfferParams params) {
    return _repository.submitOffer(params);
  }
}
