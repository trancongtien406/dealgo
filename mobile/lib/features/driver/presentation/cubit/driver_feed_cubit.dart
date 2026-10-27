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
  const DriverFeedFailed([this.error, this.sessionExpired = false]);

  /// The failure behind it, turned into text by the page (see apiErrorText).
  final Object? error;
  final bool sessionExpired;
}

class DriverFeedCubit extends Cubit<DriverFeedState> {
  DriverFeedCubit({
    required this._listOpenDriverRides,
    required this._listReadyDriverOrders,
    this.staleLocationRetries = const [
      Duration(seconds: 2),
      Duration(seconds: 4),
    ],
  }) : super(const DriverFeedIdle());

  /// Opening the app from a "new ride nearby" push (cold start / long background)
  /// asks for the list before the location reporter's first fix lands, so the server
  /// answers DRIVER_LOCATION_STALE. Wait for that fix and ask again instead of
  /// showing an error over a ride the driver was just told about.
  final List<Duration> staleLocationRetries;

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
      emit(const DriverFeedFailed(null, true));
      return;
    }
    emit(const DriverFeedLoading());
    var attempt = 0;
    late _Capture<List<OpenRide>> openedResult;
    late _Capture<List<ReadyFoodJob>> readyResult;
    while (true) {
      final opened = _capture(_listOpenDriverRides(token));
      final ready = _capture(_listReadyDriverOrders(token));
      openedResult = await opened;
      readyResult = await ready;
      if (isClosed || generation != _generation) {
        return;
      }
      final stale =
          _locationStale(openedResult.error) ||
          _locationStale(readyResult.error);
      if (!stale || attempt >= staleLocationRetries.length) {
        break;
      }
      await Future<void>.delayed(staleLocationRetries[attempt]);
      attempt += 1;
      if (isClosed || generation != _generation) {
        return;
      }
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

bool _locationStale(Object? error) {
  return error is ApiException &&
      error.statusCode == 409 &&
      error.errorCode == 'DRIVER_LOCATION_STALE';
}

bool _roleInactive(Object? error) {
  return error is ApiException &&
      error.statusCode == 403 &&
      error.errorCode == 'ROLE_NOT_ACTIVE';
}

/// Known codes keep their own sentence; anything else shows the generic load failure.
Object? _failureMessage(Object error) => error;

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
