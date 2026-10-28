import '../maps/route_geometry.dart';

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

/// Customer-only live driver GPS room for a ride (`ride-location:{id}`).
final class RideLocationRoom extends SnapshotRoom {
  const RideLocationRoom(this.rideId);

  final String rideId;

  @override
  String get name => 'ride-location:$rideId';
}

/// Customer-only live courier GPS room for a food order (`food-location:{id}`).
final class FoodLocationRoom extends SnapshotRoom {
  const FoodLocationRoom(this.orderId);

  final String orderId;

  @override
  String get name => 'food-location:$orderId';
}

/// Customer-only offers room for a bidding ride (`ride-offers:{id}`,
/// DEC-PROD-031 rev 2026-10-24). Drivers are refused by the server.
final class RideOffersRoom extends SnapshotRoom {
  const RideOffersRoom(this.rideId);

  final String rideId;

  @override
  String get name => 'ride-offers:$rideId';
}

/// `rideOffers` socket event: the offer list changed (offer / counter /
/// selection / cancel / expiry). Hint only — the customer re-GETs the ride.
class RideOffersHint {
  const RideOffersHint({
    required this.rideId,
    required this.reason,
    required this.status,
    required this.revision,
  });

  final String rideId;
  final String reason;
  final String status;
  final String revision;
}

/// `driverLocation` socket event: the assigned driver's fix, pushed by Nest on
/// each heartbeat (server-throttled). Not authoritative: GET
/// `/driver-location` is the snapshot on open and after reconnect.
class DriverLocationHint {
  const DriverLocationHint({
    required this.aggregateType,
    required this.aggregateId,
    required this.lat,
    required this.lng,
    required this.at,
    this.heading,
    this.speedMps,
  });

  final String aggregateType;
  final String aggregateId;
  final double lat;
  final double lng;
  final DateTime at;

  /// Degrees clockwise from north, when the device reported one.
  final double? heading;
  final double? speedMps;
}

/// `routeUpdated` push (DEC-PROD-031 rev 3, DRAFT): server-computed road
/// polyline for the current leg. `phase`: APPROACH (driver→pickup/store) or
/// TRIP (pickup→dropoff). Unavailable route ⇒ draw no line.
class RouteUpdateHint {
  const RouteUpdateHint({
    required this.aggregateType,
    required this.aggregateId,
    required this.phase,
    required this.reason,
    required this.route,
    required this.at,
  });

  final String aggregateType;
  final String aggregateId;
  final String phase;
  final String reason;
  final RouteGeometry route;
  final DateTime at;
}

RouteUpdateHint? parseRouteUpdateHint(Object? raw) {
  if (raw is! Map) {
    return null;
  }
  final type = raw['aggregateType'];
  final id = raw['aggregateId'];
  final phase = raw['phase'];
  final at = DateTime.tryParse('${raw['at']}');
  if (type is! String || id is! String || phase is! String || at == null) {
    return null;
  }
  return RouteUpdateHint(
    aggregateType: type,
    aggregateId: id,
    phase: phase,
    reason: raw['reason'] is String ? raw['reason'] as String : 'INITIAL',
    route: RouteGeometry.tryParse(raw['route']) ?? RouteGeometry.unavailable,
    at: at,
  );
}

/// `partnerStatus` push on the actor's private `user:` room: admin approved or
/// rejected a partner application. The page re-reads the application by REST.
class PartnerStatusHint {
  const PartnerStatusHint({
    required this.applicationId,
    required this.role,
    required this.status,
  });

  final String applicationId;

  /// `DRIVER` or `MERCHANT`.
  final String role;

  /// `APPROVED` or `REJECTED`.
  final String status;
}

PartnerStatusHint? parsePartnerStatusHint(Object? raw) {
  if (raw is! Map) {
    return null;
  }
  final id = raw['applicationId'];
  final role = raw['role'];
  final status = raw['status'];
  if (id is! String || role is! String || status is! String) {
    return null;
  }
  return PartnerStatusHint(applicationId: id, role: role, status: status);
}

/// `rideUnassigned` on the dropped driver's private `user:` room: the driver
/// lost an assigned ride (start / approach timeout, own drop, ops reassign) and
/// it went back to offers. The app leaves the job screen and says why.
class RideUnassignedHint {
  const RideUnassignedHint({
    required this.rideId,
    required this.reasonCode,
    this.actor = 'SYSTEM',
    this.fromStatus = 'ASSIGNED',
  });

  final String rideId;

  /// ASSIGNED_TIMEOUT, EN_ROUTE_TIMEOUT, OPS_REASSIGN or the driver's own code.
  final String reasonCode;
  final String actor;
  final String fromStatus;
}

RideUnassignedHint? parseRideUnassignedHint(Object? raw) {
  if (raw is! Map) {
    return null;
  }
  final id = raw['rideId'];
  if (id is! String || id.isEmpty) {
    return null;
  }
  String str(Object? v, String fallback) =>
      v is String && v.isNotEmpty ? v : fallback;
  return RideUnassignedHint(
    rideId: id,
    reasonCode: str(raw['reasonCode'], 'UNASSIGNED'),
    actor: str(raw['actor'], 'SYSTEM'),
    fromStatus: str(raw['fromStatus'], 'ASSIGNED'),
  );
}

/// `chatMessage` push on the signed-in user's private `user:` room: a new
/// transaction-chat message (ride or food). Carries the full message so an open
/// chat appends it without a GET (dedupe by [id]); a closed chat bumps its
/// unread badge. REST stays the snapshot on open / reconnect.
class ChatMessageHint {
  const ChatMessageHint({
    required this.aggregateType,
    required this.aggregateId,
    required this.id,
    required this.threadId,
    required this.senderUserId,
    required this.body,
    required this.createdAt,
  });

  /// `Ride` or `FoodOrder`.
  final String aggregateType;
  final String aggregateId;
  final String id;
  final String threadId;
  final String senderUserId;
  final String body;
  final DateTime createdAt;
}

ChatMessageHint? parseChatMessageHint(Object? raw) {
  if (raw is! Map) {
    return null;
  }
  final type = raw['aggregateType'];
  final aggregateId = raw['aggregateId'];
  final message = raw['message'];
  if (type is! String || aggregateId is! String || message is! Map) {
    return null;
  }
  final id = message['id'];
  final threadId = message['threadId'];
  final sender = message['senderUserId'];
  final body = message['body'];
  final createdAt = DateTime.tryParse('${message['createdAt']}');
  if (id is! String ||
      threadId is! String ||
      sender is! String ||
      body is! String ||
      createdAt == null) {
    return null;
  }
  return ChatMessageHint(
    aggregateType: type,
    aggregateId: aggregateId,
    id: id,
    threadId: threadId,
    senderUserId: sender,
    body: body,
    createdAt: createdAt,
  );
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

  /// Live driver positions for joined `ride-location:` / `food-location:` rooms.
  Stream<DriverLocationHint> get driverLocations;

  /// `rideOffers` hints for joined `ride-offers:` rooms (customer only).
  Stream<RideOffersHint> get rideOffers;

  /// Server-computed phase route pushes on `ride:`/`food:` rooms.
  Stream<RouteUpdateHint> get routeUpdates;

  /// Partner application decisions for the signed-in user (no subscribe needed).
  Stream<PartnerStatusHint> get partnerStatuses;

  /// `call` events on the signed-in user's private room (in-app voice calls:
  /// ringing, accepted, declined, missed, ended). Raw payload; the voice
  /// feature parses it and confirms by REST after a reconnect.
  Stream<Map<String, Object?>> get callEvents;

  /// New transaction-chat messages for the signed-in user (no subscribe needed).
  Stream<ChatMessageHint> get chatMessages;

  /// A new inbox notification for the signed-in user (`inbox` push).
  Stream<void> get inboxEvents;

  /// The signed-in driver lost an assigned ride (no subscribe needed).
  Stream<RideUnassignedHint> get rideUnassigned;

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
