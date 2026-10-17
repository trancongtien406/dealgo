import 'dart:async';

import 'package:flutter/widgets.dart';

import '../config/app_env.dart';
import 'snapshot_realtime.dart';

/// Subscribes to a snapshot room and refreshes via [onInvalidate].
///
/// On reconnect, [onInvalidate] must perform an authoritative REST GET
/// (see docs/06-data-api/realtime-api-contract.md). Mock/Fake realtime is a no-op.
class SnapshotBinding {
  SnapshotBinding({
    required this.realtime,
    required this.room,
    required this.onInvalidate,
  });

  final SnapshotRealtime realtime;
  final SnapshotRoom room;
  final VoidCallback onInvalidate;

  StreamSubscription<SnapshotHint>? _snapshots;
  StreamSubscription<void>? _reconnects;

  Future<void> start({required String? accessToken}) async {
    if (useMockData) {
      return;
    }
    final token = accessToken?.trim() ?? '';
    if (token.isEmpty) {
      return;
    }
    await realtime.connect(accessToken: token);
    await realtime.subscribe(room);
    _snapshots ??= realtime.snapshots.listen((hint) {
      if (hint.aggregateId == _aggregateId) {
        onInvalidate();
      }
    });
    _reconnects ??= realtime.reconnects.listen((_) => onInvalidate());
  }

  String get _aggregateId => switch (room) {
    RideSnapshotRoom(:final rideId) => rideId,
    FoodSnapshotRoom(:final orderId) => orderId,
  };

  Future<void> stop() async {
    await _snapshots?.cancel();
    await _reconnects?.cancel();
    _snapshots = null;
    _reconnects = null;
    if (!useMockData) {
      await realtime.unsubscribe(room);
    }
  }
}
