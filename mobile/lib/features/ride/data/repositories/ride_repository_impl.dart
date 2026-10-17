import '../../domain/entities/ride_models.dart';
import '../../domain/params/create_ride_params.dart';
import '../../domain/params/select_ride_offer_params.dart';
import '../../domain/params/submit_ride_offer_params.dart';
import '../../domain/repositories/ride_repository.dart';
import '../datasources/ride_remote_datasource.dart';

class RideRepositoryImpl implements RideRepository {
  RideRepositoryImpl(this._remote);

  final RideRemoteDataSource _remote;

  @override
  Future<List<OpenRide>> listOpenRides(String accessToken) async {
    final models = await _remote.listOpenRides(accessToken);
    return List.unmodifiable([for (final model in models) model.toEntity()]);
  }

  @override
  Future<RideView> submitOffer(SubmitRideOfferParams request) async {
    final model = await _remote.submitOffer(request);
    return model.toEntity();
  }

  @override
  Future<RideView> createRide(CreateRideParams request) async {
    final model = await _remote.createRide(request);
    return model.toEntity();
  }

  @override
  Future<RideView> getRide({
    required String accessToken,
    required String rideId,
  }) async {
    final model = await _remote.getRide(
      accessToken: accessToken,
      rideId: rideId,
    );
    return model.toEntity();
  }

  @override
  Future<RideView> selectOffer(SelectRideOfferParams request) async {
    final model = await _remote.selectOffer(request);
    return model.toEntity();
  }

  @override
  Future<RideView> cancelRide({
    required String accessToken,
    required String rideId,
  }) async {
    final model = await _remote.cancelRide(
      accessToken: accessToken,
      rideId: rideId,
    );
    return model.toEntity();
  }
}
