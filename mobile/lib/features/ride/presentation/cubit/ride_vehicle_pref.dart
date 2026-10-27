import 'package:flutter_bloc/flutter_bloc.dart';

/// Home service tiles (Bike / Car) set a soft preference before the book tab.
/// Cleared once the vehicle step consumes it — never invents MOTORBIKE silently.
enum RideVehiclePref { motorbike, car }

class RideVehiclePrefCubit extends Cubit<RideVehiclePref?> {
  RideVehiclePrefCubit() : super(null);

  void prefer(RideVehiclePref pref) => emit(pref);

  RideVehiclePref? take() {
    final pref = state;
    if (pref != null) {
      emit(null);
    }
    return pref;
  }

  void clear() => emit(null);
}
