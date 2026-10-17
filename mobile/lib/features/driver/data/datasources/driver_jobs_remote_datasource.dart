import '../../../food/domain/entities/food_models.dart';
import '../../../ride/domain/entities/ride_models.dart';
import '../../../ride/domain/params/submit_ride_offer_params.dart';

/// Driver job board + claim/offer surface. Presentation depends on this, not Dio.
abstract interface class DriverJobsRemoteDataSource {
  Future<List<OpenRide>> listOpenRides(String accessToken);

  Future<List<ReadyFoodJob>> listReadyOrders(String accessToken);

  Future<RideView> submitOffer(SubmitRideOfferRequest request);

  Future<ClaimedFoodDelivery> claimOrder({
    required String accessToken,
    required String orderId,
  });
}

/// Backward-compatible alias used by mocks, tests, and DI overrides.
typedef DriverJobsClient = DriverJobsRemoteDataSource;
