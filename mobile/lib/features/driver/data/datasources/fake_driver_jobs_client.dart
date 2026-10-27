import '../../../food/domain/entities/food_models.dart';
import '../../../../core/network/api_exception.dart';
import '../../../ride/domain/entities/ride_models.dart';
import '../../../ride/domain/params/submit_ride_offer_params.dart';
import '../../../food/domain/params/food_delivery_action.dart';
import '../../../ride/domain/params/ride_driver_action.dart';
import 'driver_jobs_remote_datasource.dart';

class FakeDriverJobsClient implements DriverJobsClient {
  FakeDriverJobsClient({
    this.openRides = const [],
    this.readyOrders = const [],
    this.openError,
    this.readyError,
    this.offerError,
    this.claimError,
    this.onOffer,
    this.onClaim,
    this.onAdvanceRide,
    this.advanceError,
  });

  List<OpenRide> openRides;
  List<ReadyFoodJob> readyOrders;
  Object? openError;
  Object? readyError;
  Object? offerError;
  Object? claimError;
  RideView Function(SubmitRideOfferRequest request)? onOffer;
  ClaimedFoodDelivery Function(String orderId)? onClaim;

  final openCalls = <String>[];
  final readyCalls = <String>[];
  final offerCalls = <SubmitRideOfferRequest>[];
  final claimCalls = <String>[];
  final rideActions = <({String rideId, RideDriverAction action})>[];
  final deliveryActions = <({String orderId, FoodDeliveryAction action})>[];
  RideView Function(String rideId, RideDriverAction action)? onAdvanceRide;

  /// Pickup codes the driver submitted with `start`, in order.
  final submittedPickupCodes = <String?>[];

  /// When set, `start` fails like the backend unless this code is submitted.
  String? expectedPickupCode;
  Object? advanceError;

  /// Codes submitted with food pickup / deliver, in order (DEC-PROD-036).
  final submittedFoodCodes = <({FoodDeliveryAction action, String? code})>[];

  /// When set, food `deliver` fails like the backend unless this code is submitted.
  String? expectedDeliveryCode;

  /// When set, food `pickup` fails like the backend unless this code is submitted.
  String? expectedHandoverCode;

  @override
  Future<List<OpenRide>> listOpenRides(String accessToken) async {
    openCalls.add(accessToken);
    final error = openError;
    if (error != null) {
      throw error;
    }
    return List.unmodifiable(openRides);
  }

  @override
  Future<List<ReadyFoodJob>> listReadyOrders(String accessToken) async {
    readyCalls.add(accessToken);
    final error = readyError;
    if (error != null) {
      throw error;
    }
    return List.unmodifiable(readyOrders);
  }

  @override
  Future<RideView> submitOffer(SubmitRideOfferRequest request) async {
    offerCalls.add(request);
    final error = offerError;
    if (error != null) {
      throw error;
    }
    final handler = onOffer;
    if (handler == null) {
      throw const ApiException(
        statusCode: 500,
        message: 'FakeDriverJobsClient has no offer handler',
        errorCode: 'FAKE_MISSING_HANDLER',
      );
    }
    return handler(request);
  }

  @override
  Future<ClaimedFoodDelivery> claimOrder({
    required String accessToken,
    required String orderId,
  }) async {
    claimCalls.add(orderId);
    final error = claimError;
    if (error != null) {
      throw error;
    }
    final handler = onClaim;
    if (handler == null) {
      throw const ApiException(
        statusCode: 500,
        message: 'FakeDriverJobsClient has no claim handler',
        errorCode: 'FAKE_MISSING_HANDLER',
      );
    }
    return handler(orderId);
  }

  @override
  Future<RideView> advanceRide({
    required String accessToken,
    required String rideId,
    required RideDriverAction action,
    String? pickupCode,
  }) async {
    rideActions.add((rideId: rideId, action: action));
    if (action == RideDriverAction.start) {
      submittedPickupCodes.add(pickupCode);
      final expected = expectedPickupCode;
      if (expected != null && pickupCode != expected) {
        throw const ApiException(
          statusCode: 422,
          message: 'Pickup code does not match',
          errorCode: 'RIDE_PICKUP_CODE_INVALID',
        );
      }
    }
    final error = advanceError;
    if (error != null) {
      throw error;
    }
    final handler = onAdvanceRide;
    if (handler == null) {
      throw const ApiException(
        statusCode: 500,
        message: 'FakeDriverJobsClient has no ride action handler',
        errorCode: 'FAKE_MISSING_HANDLER',
      );
    }
    return handler(rideId, action);
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
  }) async {
    deliveryActions.add((orderId: orderId, action: action));
    submittedFoodCodes.add((action: action, code: code));
    final expected = switch (action) {
      FoodDeliveryAction.deliver => expectedDeliveryCode,
      FoodDeliveryAction.pickup => expectedHandoverCode,
      FoodDeliveryAction.fail => null,
    };
    if (expected != null && code != expected) {
      final prefix = action == FoodDeliveryAction.deliver
          ? 'FOOD_DELIVERY_CODE'
          : 'FOOD_HANDOVER_CODE';
      throw ApiException(
        statusCode: 422,
        message: 'Code required or wrong',
        errorCode: code == null ? '${prefix}_REQUIRED' : '${prefix}_INVALID',
      );
    }
    final error = advanceError;
    if (error != null) {
      throw error;
    }
    return ClaimedFoodDelivery(
      id: orderId,
      status: switch (action) {
        FoodDeliveryAction.pickup => 'PICKED_UP',
        FoodDeliveryAction.deliver => 'DELIVERED',
        FoodDeliveryAction.fail => 'FAILED',
      },
    );
  }
}
