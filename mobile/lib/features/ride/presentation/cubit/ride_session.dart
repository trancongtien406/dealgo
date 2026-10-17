import 'package:flutter_bloc/flutter_bloc.dart';

class RideSessionCubit extends Cubit<String?> {
  RideSessionCubit() : super(null);

  void remember(String rideId) {
    if (state == rideId) {
      return;
    }
    emit(rideId);
  }

  void clear() {
    if (state == null) {
      return;
    }
    emit(null);
  }
}
