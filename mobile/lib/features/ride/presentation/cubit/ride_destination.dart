import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../places/domain/place.dart';

/// Destination chosen outside the booking tab (home "Bạn muốn đi đâu?"),
/// handed to the ride map once and then cleared.
class RideDestinationCubit extends Cubit<PlaceOption?> {
  RideDestinationCubit() : super(null);

  void choose(PlaceOption place) => emit(place);

  PlaceOption? take() {
    final place = state;
    if (place != null) {
      emit(null);
    }
    return place;
  }
}
