import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/realtime/realtime_refresh_watcher.dart';
import '../../../../core/realtime/snapshot_realtime.dart';

import '../../domain/entities/ride_models.dart';
import '../../domain/params/cancel_ride_params.dart';
import '../../domain/params/get_ride_params.dart';
import '../../domain/params/select_ride_offer_params.dart';
import '../../domain/usecases/cancel_ride.dart';
import '../../domain/usecases/get_ride.dart';
import '../../domain/usecases/select_ride_offer.dart';

class RideOffersCubit extends Cubit<int> {
  RideOffersCubit({
    required this._getRide,
    required this._selectRideOffer,
    required this._cancelRide,
    this._realtime,
  }) : super(0);

  final GetRide _getRide;
  final SelectRideOffer _selectRideOffer;
  final CancelRide _cancelRide;
  final SnapshotRealtime? _realtime;
  RealtimeRefreshWatcher? _watcher;

  /// Live offer list (DEC-PROD-031 rev 2026-10-24): `rideOffers` / `ride:` hints
  /// and reconnects each trigger one REST reload; no polling.
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
    await watcher.start(accessToken: accessToken, initialRefresh: false);
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

  Future<RideView> load({required String accessToken, required String rideId}) {
    return _getRide(GetRideParams(accessToken: accessToken, rideId: rideId));
  }

  Future<RideView> select(SelectRideOfferParams request) {
    return _selectRideOffer(request);
  }

  Future<RideView> cancel({
    required String accessToken,
    required String rideId,
  }) {
    return _cancelRide(
      CancelRideParams(accessToken: accessToken, rideId: rideId),
    );
  }
}
