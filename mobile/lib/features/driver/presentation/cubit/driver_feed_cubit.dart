import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/network/api_exception.dart';
import '../../../food/domain/entities/food_models.dart';
import '../../../ride/domain/entities/ride_models.dart';
import '../../domain/usecases/list_open_driver_rides.dart';
import '../../domain/usecases/list_ready_driver_orders.dart';

sealed class DriverFeedState {
  const DriverFeedState();
}

final class DriverFeedIdle extends DriverFeedState {
  const DriverFeedIdle();
}

final class DriverFeedLoading extends DriverFeedState {
  const DriverFeedLoading();
}

final class DriverFeedReady extends DriverFeedState {
  const DriverFeedReady({required this.rides, required this.food});

  final List<OpenRide> rides;
  final List<ReadyFoodJob> food;
}

final class DriverFeedIneligible extends DriverFeedState {
  const DriverFeedIneligible();
}

final class DriverFeedFailed extends DriverFeedState {
  const DriverFeedFailed(this.message);

  final String message;
}

class DriverFeedCubit extends Cubit<DriverFeedState> {
  DriverFeedCubit({
    required ListOpenDriverRides listOpenDriverRides,
    required ListReadyDriverOrders listReadyDriverOrders,
  }) : _listOpenDriverRides = listOpenDriverRides,
       _listReadyDriverOrders = listReadyDriverOrders,
       super(const DriverFeedIdle());

  final ListOpenDriverRides _listOpenDriverRides;
  final ListReadyDriverOrders _listReadyDriverOrders;
  var _generation = 0;

  Future<void> sync({
    required bool online,
    required String? accessToken,
  }) async {
    final generation = ++_generation;
    if (!online) {
      emit(const DriverFeedIdle());
      return;
    }
    final token = accessToken?.trim() ?? '';
    if (token.isEmpty) {
      emit(const DriverFeedFailed('Phiên đăng nhập không còn hiệu lực'));
      return;
    }
    emit(const DriverFeedLoading());
    final opened = _capture(_listOpenDriverRides(token));
    final ready = _capture(_listReadyDriverOrders(token));
    final openedResult = await opened;
    final readyResult = await ready;
    if (isClosed || generation != _generation) {
      return;
    }
    if (_roleInactive(openedResult.error) || _roleInactive(readyResult.error)) {
      emit(const DriverFeedIneligible());
      return;
    }
    final failure = openedResult.error ?? readyResult.error;
    if (failure != null) {
      emit(DriverFeedFailed(_failureMessage(failure)));
      return;
    }
    emit(
      DriverFeedReady(
        rides: List.unmodifiable(openedResult.value ?? const <OpenRide>[]),
        food: List.unmodifiable(readyResult.value ?? const <ReadyFoodJob>[]),
      ),
    );
  }
}

OpenRide? openRideFrom(DriverFeedState state, String id) {
  if (state is! DriverFeedReady) {
    return null;
  }
  for (final ride in state.rides) {
    if (ride.id == id) {
      return ride;
    }
  }
  return null;
}

ReadyFoodJob? readyFoodFrom(DriverFeedState state, String id) {
  if (state is! DriverFeedReady) {
    return null;
  }
  for (final job in state.food) {
    if (job.id == id) {
      return job;
    }
  }
  return null;
}

bool _roleInactive(Object? error) {
  return error is ApiException &&
      error.statusCode == 403 &&
      error.errorCode == 'ROLE_NOT_ACTIVE';
}

String _failureMessage(Object error) {
  if (error is ApiException && error.message.isNotEmpty) {
    return error.message;
  }
  return 'Không tải được yêu cầu';
}

class _Capture<T> {
  const _Capture.ok(this.value) : error = null;

  const _Capture.fail(this.error) : value = null;

  final T? value;
  final Object? error;
}

Future<_Capture<T>> _capture<T>(Future<T> future) async {
  try {
    return _Capture.ok(await future);
  } catch (error) {
    return _Capture.fail(error);
  }
}
