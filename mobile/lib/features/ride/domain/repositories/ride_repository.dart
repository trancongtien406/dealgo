import '../entities/ride_models.dart';
import '../params/create_ride_params.dart';
import '../params/select_ride_offer_params.dart';
import '../params/submit_ride_offer_params.dart';

abstract interface class RideRepository {
  Future<List<OpenRide>> listOpenRides(String accessToken);

  Future<RideView> submitOffer(SubmitRideOfferParams request);

  Future<RideView> createRide(CreateRideParams request);

  Future<RideView> getRide({
    required String accessToken,
    required String rideId,
  });

  Future<RideView> selectOffer(SelectRideOfferParams request);

  Future<RideView> cancelRide({
    required String accessToken,
    required String rideId,
  });
}
