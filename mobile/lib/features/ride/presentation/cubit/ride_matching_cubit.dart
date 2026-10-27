import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/realtime/realtime_refresh_watcher.dart';
import '../../../../core/realtime/snapshot_realtime.dart';
import '../../domain/entities/ride_models.dart';
import '../../domain/params/cancel_ride_params.dart';
import '../../domain/params/get_ride_params.dart';
import '../../domain/usecases/cancel_ride.dart';
import '../../domain/usecases/get_ride.dart';

class RideMatchingCubit extends Cubit<int> {
  RideMatchingCubit({
    required this._getRide,
    required this._cancelRide,
    this._realtime,
  }) : super(0);

  final GetRide _getRide;
  final CancelRide _cancelRide;
  final SnapshotRealtime? _realtime;
  RealtimeRefreshWatcher? _watcher;

  Future<RideView> load({required String accessToken, required String rideId}) {
    return _getRide(GetRideParams(accessToken: accessToken, rideId: rideId));
  }

  /// DEC-PROD-031 rev 2026-10-24: no offer polling. Offers arrive on the
  /// customer-only `ride-offers:{id}` room, status on `ride:{id}`; each hint and
  /// each reconnect triggers one authoritative REST reload via [refresh].
  Future<void> watch({
    required String accessToken,
    required String rideId,
    required Future<void> Function() refresh,
  }) async {
    await stopWatching();
    final realtime = _realtime;
    if (realtime == null) {
      return;
    }
    final watcher = RealtimeRefreshWatcher(
      realtime: realtime,
      rooms: [RideSnapshotRoom(rideId), RideOffersRoom(rideId)],
      refresh: refresh,
      matchesSnapshot: (hint) => hint.aggregateId == rideId,
      matchesRideOffers: (hint) => hint.rideId == rideId,
    );
    _watcher = watcher;
    // The page already did its first GET; the watcher adds one after subscribe.
    await watcher.start(accessToken: accessToken);
  }

  Future<void> stopWatching() async {
    final watcher = _watcher;
    _watcher = null;
    await watcher?.stop();
  }

  Future<RideView> cancel({
    required String accessToken,
    required String rideId,
  }) {
    return _cancelRide(
      CancelRideParams(accessToken: accessToken, rideId: rideId),
    );
  }

  @override
  Future<void> close() async {
    await stopWatching();
    return super.close();
  }
}
