import '../../domain/params/create_ride_params.dart';
import '../../domain/params/ride_driver_action.dart';
import '../../domain/params/select_ride_offer_params.dart';
import '../../domain/params/submit_ride_offer_params.dart';
import '../models/ride_models.dart';

abstract interface class RideRemoteDataSource {
  Future<List<OpenRideModel>> listOpenRides(String accessToken);

  Future<void> dismissRide({
    required String accessToken,
    required String rideId,
  });

  Future<RideViewModel> submitOffer(SubmitRideOfferParams request);

  Future<RideViewModel> createRide(CreateRideParams request);

  Future<RideViewModel> getRide({
    required String accessToken,
    required String rideId,
  });

  Future<RideViewModel> selectOffer(SelectRideOfferParams request);

  Future<RideViewModel> cancelRide({
    required String accessToken,
    required String rideId,
  });

  Future<RideViewModel> advanceRide({
    required String accessToken,
    required String rideId,
    required RideDriverAction action,
    String? pickupCode,
  });
}

/// Backward-compatible alias used by mocks, tests, and DI overrides.
typedef RideClient = RideRemoteDataSource;
