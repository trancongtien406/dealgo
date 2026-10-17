import '../../../food/domain/entities/food_models.dart';
import '../../../ride/domain/entities/ride_models.dart';
import '../../../ride/domain/params/submit_ride_offer_params.dart';
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
}
