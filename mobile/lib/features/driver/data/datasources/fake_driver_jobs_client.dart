import '../../../food/domain/entities/food_models.dart';
import '../../../../core/network/api_exception.dart';
import '../../../ride/domain/entities/ride_models.dart';
import '../../../ride/domain/params/submit_ride_offer_params.dart';
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
}
