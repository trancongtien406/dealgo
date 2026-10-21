import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../ride/domain/entities/ride_models.dart';
import '../../../ride/domain/params/submit_ride_offer_params.dart';
import '../../domain/usecases/submit_driver_ride_offer.dart';

class DriverOfferCubit extends Cubit<int> {
  DriverOfferCubit({required this._submitDriverRideOffer}) : super(0);

  final SubmitDriverRideOffer _submitDriverRideOffer;

  Future<RideView> submit(SubmitRideOfferRequest request) {
    return _submitDriverRideOffer(request);
  }
}
