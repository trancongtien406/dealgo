import 'dart:async';

import 'snapshot_realtime.dart';

/// Socket-driven refresh for a screen that used to poll (DEC-PROD-031 rev 2026-10-24).
///
/// * one REST snapshot after the rooms are joined (closes the gap between the
///   screen's first GET and the subscribe);
/// * one REST refetch per matching hint (`snapshot` / `rideOffers`);
/// * exactly one REST refetch per reconnect;
/// * refreshes never overlap: hints arriving mid-flight coalesce into one
///   trailing refetch, so a burst of offers costs at most two requests.
/// No timers — nothing is requested while nothing changes.
class RealtimeRefreshWatcher {
  RealtimeRefreshWatcher({
    required this.realtime,
    required this.rooms,
    required this.refresh,
    this.matchesSnapshot,
    this.matchesRideOffers,
  });

  final SnapshotRealtime realtime;
  final List<SnapshotRoom> rooms;
  final Future<void> Function() refresh;
  final bool Function(SnapshotHint hint)? matchesSnapshot;
  final bool Function(RideOffersHint hint)? matchesRideOffers;

  final _subs = <StreamSubscription<Object?>>[];
  var _running = false;
  var _pending = false;
  var _stopped = false;

  Future<void> start({
    required String accessToken,
    bool initialRefresh = true,
  }) async {
    final token = accessToken.trim();
    if (token.isEmpty) {
      return;
    }
    final matchSnap = matchesSnapshot;
    if (matchSnap != null) {
      _subs.add(
        realtime.snapshots.listen((hint) {
          if (matchSnap(hint)) {
            trigger();
          }
        }),
      );
    }
    final matchOffers = matchesRideOffers;
    if (matchOffers != null) {
      _subs.add(
        realtime.rideOffers.listen((hint) {
          if (matchOffers(hint)) {
            trigger();
          }
        }),
      );
    }
    _subs.add(realtime.reconnects.listen((_) => trigger()));
    await realtime.connect(accessToken: token);
    for (final room in rooms) {
      await realtime.subscribe(room);
    }
    if (initialRefresh && !_stopped) {
      trigger();
    }
  }

  /// Runs [refresh] now, or once more after the in-flight one finishes.
  void trigger() {
    if (_stopped) {
      return;
    }
    if (_running) {
      _pending = true;
      return;
    }
    _running = true;
    unawaited(_run());
  }

  Future<void> _run() async {
    try {
      do {
        _pending = false;
        try {
          await refresh();
        } catch (_) {
          // REST failure: the next hint / reconnect retries.
        }
      } while (_pending && !_stopped);
    } finally {
      _running = false;
    }
  }

  Future<void> stop() async {
    _stopped = true;
    for (final sub in _subs) {
      unawaited(sub.cancel());
    }
    _subs.clear();
    for (final room in rooms) {
      try {
        await realtime.unsubscribe(room);
      } catch (_) {}
    }
  }
}
