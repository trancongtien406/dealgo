import '../../../food/domain/entities/food_models.dart';
import '../../../ride/domain/entities/ride_models.dart';
import '../../../ride/domain/params/submit_ride_offer_params.dart';

abstract interface class DriverJobsRepository {
  Future<List<OpenRide>> listOpenRides(String accessToken);

  Future<List<ReadyFoodJob>> listReadyOrders(String accessToken);

  Future<RideView> submitOffer(SubmitRideOfferRequest request);

  Future<ClaimedFoodDelivery> claimOrder({
    required String accessToken,
    required String orderId,
  });
}
