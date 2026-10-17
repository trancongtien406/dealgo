/// Hint-only realtime. REST GET remains authoritative after reconnect.
sealed class SnapshotRoom {
  const SnapshotRoom();

  String get name;
}

final class RideSnapshotRoom extends SnapshotRoom {
  const RideSnapshotRoom(this.rideId);

  final String rideId;

  @override
  String get name => 'ride:$rideId';
}

final class FoodSnapshotRoom extends SnapshotRoom {
  const FoodSnapshotRoom(this.orderId);

  final String orderId;

  @override
  String get name => 'food:$orderId';
}

class SnapshotHint {
  const SnapshotHint({
    required this.aggregateType,
    required this.aggregateId,
    required this.status,
    required this.revision,
    required this.occurredAt,
    this.eventType,
  });

  final String? eventType;
  final String aggregateType;
  final String aggregateId;
  final String status;
  final String revision;
  final String occurredAt;
}

/// Socket.IO snapshot client. On reconnect, listeners must GET REST and reconcile.
abstract interface class SnapshotRealtime {
  Stream<SnapshotHint> get snapshots;

  /// Fires after a successful reconnect (and after re-subscribe of rooms).
  /// Callers must trigger an authoritative REST GET — do not trust the last hint.
  Stream<void> get reconnects;

  Future<void> connect({required String accessToken});

  Future<void> disconnect();

  Future<void> subscribe(SnapshotRoom room);

  Future<void> unsubscribe(SnapshotRoom room);
}
