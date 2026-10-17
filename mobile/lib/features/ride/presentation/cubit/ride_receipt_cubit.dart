import 'package:flutter_bloc/flutter_bloc.dart';

import '../../domain/entities/ride_models.dart';
import '../../domain/params/get_ride_params.dart';
import '../../domain/usecases/get_ride.dart';

class RideReceiptCubit extends Cubit<int> {
  RideReceiptCubit({required this._getRide}) : super(0);

  final GetRide _getRide;

  Future<RideView> load({required String accessToken, required String rideId}) {
    return _getRide(GetRideParams(accessToken: accessToken, rideId: rideId));
  }
}
