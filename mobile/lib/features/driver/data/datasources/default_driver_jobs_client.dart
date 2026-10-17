import '../../../food/data/datasources/food_remote_datasource.dart';
import '../../../food/domain/entities/food_models.dart';
import '../../../ride/data/datasources/ride_remote_datasource.dart';
import '../../../ride/domain/entities/ride_models.dart';
import '../../../ride/domain/params/submit_ride_offer_params.dart';
import 'driver_jobs_remote_datasource.dart';

class DefaultDriverJobsClient implements DriverJobsClient {
  DefaultDriverJobsClient({required this.rides, required this.food});

  final RideClient rides;
  final FoodClient food;

  @override
  Future<List<OpenRide>> listOpenRides(String accessToken) async {
    final models = await rides.listOpenRides(accessToken);
    return List.unmodifiable([for (final model in models) model.toEntity()]);
  }

  @override
  Future<List<ReadyFoodJob>> listReadyOrders(String accessToken) {
    return food.listReadyOrders(accessToken);
  }

  @override
  Future<RideView> submitOffer(SubmitRideOfferRequest request) async {
    final model = await rides.submitOffer(request);
    return model.toEntity();
  }

  @override
  Future<ClaimedFoodDelivery> claimOrder({
    required String accessToken,
    required String orderId,
  }) {
    return food.claimOrder(accessToken: accessToken, orderId: orderId);
  }
}
