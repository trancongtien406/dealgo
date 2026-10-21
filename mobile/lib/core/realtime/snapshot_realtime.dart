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

/// Merchant kitchen board (DEC-PROD-041).
final class StoreSnapshotRoom extends SnapshotRoom {
  const StoreSnapshotRoom(this.storeId);

  final String storeId;

  @override
  String get name => 'store:$storeId';
}

class SnapshotHint {
  const SnapshotHint({
    required this.aggregateType,
    required this.aggregateId,
    required this.status,
    required this.revision,
    required this.occurredAt,
    this.eventType,
    this.storeId,
  });

  final String? eventType;
  final String aggregateType;
  final String aggregateId;
  final String status;
  final String revision;
  final String occurredAt;
  final String? storeId;
}

/// Socket.IO snapshot client. On reconnect, listeners must GET REST and reconcile.
abstract interface class SnapshotRealtime {
  Stream<SnapshotHint> get snapshots;

  /// Fires after a successful reconnect (and after re-subscribe of rooms).
  /// Callers must trigger an authoritative REST GET — do not trust the last hint.
  Stream<void> get reconnects;

  /// True while the socket reports connected (false for fake until [connect]).
  bool get isConnected;

  Future<void> connect({required String accessToken});

  Future<void> disconnect();

  Future<void> subscribe(SnapshotRoom room);

  Future<void> unsubscribe(SnapshotRoom room);
}
