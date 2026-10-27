import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/network/api_exception.dart';
import '../../../../core/realtime/realtime_refresh_watcher.dart';
import '../../../../core/realtime/snapshot_realtime.dart';
import '../../../ride/domain/entities/ride_models.dart';
import '../../../ride/domain/params/get_ride_params.dart';
import '../../../ride/domain/params/submit_ride_offer_params.dart';
import '../../../ride/domain/usecases/get_ride.dart';
import '../../domain/usecases/submit_driver_ride_offer.dart';

enum DriverOfferSelection { waiting, selected, lost }

/// Still negotiating → wait; the ride moved on and is still readable → it is ours.
DriverOfferSelection driverOfferSelectionFor(RideStatus status) =>
    switch (status) {
      RideStatus.negotiating => DriverOfferSelection.waiting,
      RideStatus.cancelled || RideStatus.expired => DriverOfferSelection.lost,
      _ => DriverOfferSelection.selected,
    };

/// State = this driver's offer outcome. DEC-PROD-031 rev 2026-10-24: no poll;
/// the `ride:{id}` status hint (ASSIGNED / CANCELLED / EXPIRED) and each
/// reconnect trigger one REST check. GET returns only this driver's own offer.
class DriverOfferCubit extends Cubit<DriverOfferSelection> {
  DriverOfferCubit({
    required this._submitDriverRideOffer,
    this._getRide,
    this._realtime,
  }) : super(DriverOfferSelection.waiting);

  final SubmitDriverRideOffer _submitDriverRideOffer;
  final GetRide? _getRide;
  final SnapshotRealtime? _realtime;
  RealtimeRefreshWatcher? _watcher;

  Future<RideView> submit(SubmitRideOfferRequest request) {
    return _submitDriverRideOffer(request);
  }

  Future<void> watchSelection({
    required String accessToken,
    required String rideId,
  }) async {
    await stopWatching();
    final realtime = _realtime;
    if (realtime == null || _getRide == null) {
      return;
    }
    final watcher = RealtimeRefreshWatcher(
      realtime: realtime,
      rooms: [RideSnapshotRoom(rideId)],
      refresh: () => checkSelection(accessToken: accessToken, rideId: rideId),
      matchesSnapshot: (hint) => hint.aggregateId == rideId,
    );
    _watcher = watcher;
    await watcher.start(accessToken: accessToken);
  }

  Future<void> checkSelection({
    required String accessToken,
    required String rideId,
  }) async {
    final getRide = _getRide;
    if (getRide == null || isClosed || state != DriverOfferSelection.waiting) {
      return;
    }
    DriverOfferSelection next;
    try {
      final view = await getRide(
        GetRideParams(accessToken: accessToken, rideId: rideId),
      );
      next = driverOfferSelectionFor(view.status);
    } on ApiException catch (error) {
      if (error.statusCode != 404) {
        return;
      }
      // Another driver was chosen: the ride is no longer readable for us.
      next = DriverOfferSelection.lost;
    }
    if (isClosed) {
      return;
    }
    emit(next);
    if (next != DriverOfferSelection.waiting) {
      // Not awaited: we are inside the watcher's own refresh.
      unawaited(stopWatching());
    }
  }

  Future<void> stopWatching() async {
    final watcher = _watcher;
    _watcher = null;
    await watcher?.stop();
  }

  @override
  Future<void> close() async {
    await stopWatching();
    return super.close();
  }
}
