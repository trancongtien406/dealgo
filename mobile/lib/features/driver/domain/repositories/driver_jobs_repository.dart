import '../../../food/domain/entities/food_models.dart';
import '../../../ride/domain/entities/ride_models.dart';
import '../../../ride/domain/params/submit_ride_offer_params.dart';
import '../../../food/domain/params/food_delivery_action.dart';
import '../../../ride/domain/params/ride_driver_action.dart';

abstract interface class DriverJobsRepository {
  Future<List<OpenRide>> listOpenRides(String accessToken);

  Future<List<ReadyFoodJob>> listReadyOrders(String accessToken);

  Future<RideView> submitOffer(SubmitRideOfferRequest request);

  Future<ClaimedFoodDelivery> claimOrder({
    required String accessToken,
    required String orderId,
  });

  /// Assigned-driver trip transition (en-route / arrived / start / complete).
  Future<RideView> advanceRide({
    required String accessToken,
    required String rideId,
    required RideDriverAction action,
    String? pickupCode,
  });

  /// Assigned-driver delivery transition (pickup / deliver / fail).
  Future<ClaimedFoodDelivery> advanceDelivery({
    required String accessToken,
    required String orderId,
    required FoodDeliveryAction action,

    /// DEC-PROD-036: handover code (pickup) or delivery code (deliver).
    String? code,

    /// Why the delivery failed (FOOD_FAIL_REASONS) and the note for OTHER.
    String? failReason,
    String? failNote,
  });
}
