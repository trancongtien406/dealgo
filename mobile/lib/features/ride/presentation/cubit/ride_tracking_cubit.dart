import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/network/request_failure.dart';
import '../../../active_job/presentation/active_job_cache.dart';
import '../utils/ride_offline_snapshot.dart';
import '../../../../core/realtime/snapshot_binding.dart';
import '../../../../core/realtime/snapshot_realtime.dart';
import '../../domain/entities/ride_models.dart';
import '../../domain/params/get_ride_params.dart';
import '../../domain/usecases/get_ride.dart';

sealed class RideTrackingState {
  const RideTrackingState();

  RideView? get ride;
  bool get busy;
}

final class RideTrackingLoading extends RideTrackingState {
  const RideTrackingLoading({this.ride, this.busy = true});

  @override
  final RideView? ride;

  @override
  final bool busy;
}

final class RideTrackingReady extends RideTrackingState {
  const RideTrackingReady(this.ride, {this.busy = false});

  @override
  final RideView ride;

  @override
  final bool busy;
}

final class RideTrackingOffline extends RideTrackingState {
  const RideTrackingOffline({this.ride, this.busy = false, this.cause});

  @override
  final RideView? ride;

  @override
  final bool busy;

  final Object? cause;
}

/// Owns snapshot subscription; invalidate always refreshes via REST GET.
class RideTrackingCubit extends Cubit<RideTrackingState> {
  RideTrackingCubit({
    required this._getRide,
    required this.realtime,
    this._offlineCache,
  }) : super(const RideTrackingLoading());

  final GetRide _getRide;
  final SnapshotRealtime realtime;
  final ActiveJobCache? _offlineCache;

  SnapshotBinding? _binding;
  String? _rideId;
  String? _accessToken;
  var _inFlight = false;

  Future<void> start({
    required String rideId,
    required String? accessToken,
  }) async {
    _rideId = rideId;
    _accessToken = accessToken;
    await refresh();
    await _binding?.stop();
    final binding = SnapshotBinding(
      realtime: realtime,
      room: RideSnapshotRoom(rideId),
      onInvalidate: () {
        // Snapshot hints are not source of truth — re-fetch from API.
        refresh();
      },
    );
    _binding = binding;
    await binding.start(accessToken: accessToken);
  }

  Future<void> refresh() async {
    // Realtime invalidations can arrive after the page closed the cubit.
    if (isClosed || _inFlight) {
      return;
    }
    final rideId = _rideId;
    final token = _accessToken;
    if (rideId == null) {
      return;
    }
    if (token == null || token.isEmpty) {
      emit(RideTrackingOffline(ride: state.ride, cause: sessionExpiredFailure));
      return;
    }
    _inFlight = true;
    final previous = state.ride;
    emit(
      previous == null
          ? const RideTrackingLoading()
          : RideTrackingReady(previous, busy: true),
    );
    try {
      final ride = await _getRide(
        GetRideParams(accessToken: token, rideId: rideId),
      );
      if (isClosed) {
        return;
      }
      emit(RideTrackingReady(ride));
      unawaited(
        _offlineCache?.recordJob(
          rideOfflineSnapshot(ride),
          terminal: ride.status.isTerminal,
          assignedDriverId: ride.assignedDriverId,
        ),
      );
    } catch (error) {
      if (isClosed) {
        return;
      }
      emit(RideTrackingOffline(ride: previous, cause: error));
    } finally {
      _inFlight = false;
    }
  }

  @override
  Future<void> close() async {
    await _binding?.stop();
    _binding = null;
    return super.close();
  }
}
