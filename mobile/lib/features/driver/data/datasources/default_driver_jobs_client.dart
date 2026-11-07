import '../../../food/data/datasources/food_remote_datasource.dart';
import '../../../food/domain/entities/food_models.dart';
import '../../../ride/data/datasources/ride_remote_datasource.dart';
import '../../../ride/domain/entities/ride_models.dart';
import '../../../ride/domain/params/submit_ride_offer_params.dart';
import '../../../ride/domain/params/ride_driver_action.dart';
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
  Future<void> dismissRide({
    required String accessToken,
    required String rideId,
  }) {
    return rides.dismissRide(accessToken: accessToken, rideId: rideId);
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

  @override
  Future<RideView> advanceRide({
    required String accessToken,
    required String rideId,
    required RideDriverAction action,
    String? pickupCode,
  }) async {
    final model = await rides.advanceRide(
      accessToken: accessToken,
      rideId: rideId,
      action: action,
      pickupCode: pickupCode,
    );
    return model.toEntity();
  }

  @override
  Future<ClaimedFoodDelivery> advanceDelivery({
    required String accessToken,
    required String orderId,
    required FoodDeliveryAction action,

    /// DEC-PROD-036: handover code (pickup) or delivery code (deliver).
    String? code,

    /// Why the delivery failed (FOOD_FAIL_REASONS) and the note for OTHER.
    String? failReason,
    String? failNote,
  }) {
    return food.advanceDelivery(
      accessToken: accessToken,
      orderId: orderId,
      action: action,
      code: code,
      failReason: failReason,
      failNote: failNote,
    );
  }
}
