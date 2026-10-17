import 'package:flutter_bloc/flutter_bloc.dart';

import '../../domain/entities/ride_models.dart';
import '../../domain/params/cancel_ride_params.dart';
import '../../domain/params/get_ride_params.dart';
import '../../domain/params/select_ride_offer_params.dart';
import '../../domain/usecases/cancel_ride.dart';
import '../../domain/usecases/get_ride.dart';
import '../../domain/usecases/select_ride_offer.dart';

class RideOffersCubit extends Cubit<int> {
  RideOffersCubit({
    required this._getRide,
    required this._selectRideOffer,
    required this._cancelRide,
  }) : super(0);

  final GetRide _getRide;
  final SelectRideOffer _selectRideOffer;
  final CancelRide _cancelRide;

  Future<RideView> load({required String accessToken, required String rideId}) {
    return _getRide(GetRideParams(accessToken: accessToken, rideId: rideId));
  }

  Future<RideView> select(SelectRideOfferParams request) {
    return _selectRideOffer(request);
  }

  Future<RideView> cancel({
    required String accessToken,
    required String rideId,
  }) {
    return _cancelRide(
      CancelRideParams(accessToken: accessToken, rideId: rideId),
    );
  }
}
