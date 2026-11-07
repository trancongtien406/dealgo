import '../../../food/domain/entities/food_models.dart';
import '../../../ride/domain/entities/ride_models.dart';
import '../../../ride/domain/params/submit_ride_offer_params.dart';
import '../../../food/domain/params/food_delivery_action.dart';
import '../../../ride/domain/params/ride_driver_action.dart';
import '../../domain/repositories/driver_jobs_repository.dart';
import '../datasources/driver_jobs_remote_datasource.dart';

class DriverJobsRepositoryImpl implements DriverJobsRepository {
  DriverJobsRepositoryImpl(this._remote);

  final DriverJobsRemoteDataSource _remote;

  @override
  Future<List<OpenRide>> listOpenRides(String accessToken) {
    return _remote.listOpenRides(accessToken);
  }

  @override
  Future<void> dismissRide({
    required String accessToken,
    required String rideId,
  }) {
    return _remote.dismissRide(accessToken: accessToken, rideId: rideId);
  }

  @override
  Future<List<ReadyFoodJob>> listReadyOrders(String accessToken) {
    return _remote.listReadyOrders(accessToken);
  }

  @override
  Future<RideView> submitOffer(SubmitRideOfferRequest request) {
    return _remote.submitOffer(request);
  }

  @override
  Future<ClaimedFoodDelivery> claimOrder({
    required String accessToken,
    required String orderId,
  }) {
    return _remote.claimOrder(accessToken: accessToken, orderId: orderId);
  }

  @override
  Future<RideView> advanceRide({
    required String accessToken,
    required String rideId,
    required RideDriverAction action,
    String? pickupCode,
  }) {
    return _remote.advanceRide(
      accessToken: accessToken,
      rideId: rideId,
      action: action,
      pickupCode: pickupCode,
    );
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
    return _remote.advanceDelivery(
      accessToken: accessToken,
      orderId: orderId,
      action: action,
      code: code,
      failReason: failReason,
      failNote: failNote,
    );
  }
}
