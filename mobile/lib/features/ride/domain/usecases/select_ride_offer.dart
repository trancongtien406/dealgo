import '../entities/ride_models.dart';
import '../params/select_ride_offer_params.dart';
import '../repositories/ride_repository.dart';

class SelectRideOffer {
  const SelectRideOffer(this._repository);

  final RideRepository _repository;

  Future<RideView> call(SelectRideOfferParams params) {
    return _repository.selectOffer(params);
  }
}
