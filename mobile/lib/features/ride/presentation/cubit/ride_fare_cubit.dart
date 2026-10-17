import 'package:flutter_bloc/flutter_bloc.dart';

import '../../domain/entities/ride_models.dart';
import '../../domain/params/create_ride_params.dart';
import '../../domain/usecases/create_ride.dart';

class RideFareCubit extends Cubit<int> {
  RideFareCubit({required this._createRide}) : super(0);

  final CreateRide _createRide;

  Future<RideView> create(CreateRideParams request) {
    return _createRide(request);
  }
}
