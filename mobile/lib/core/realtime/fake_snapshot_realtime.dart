import 'dart:async';

import 'snapshot_realtime.dart';

/// No-op realtime used for mock/demo and widget tests.
class FakeSnapshotRealtime implements SnapshotRealtime {
  final _snapshots = StreamController<SnapshotHint>.broadcast();
  final _reconnects = StreamController<void>.broadcast();
  final _driverLocations = StreamController<DriverLocationHint>.broadcast();
  final _rideOffers = StreamController<RideOffersHint>.broadcast();
  final _routeUpdates = StreamController<RouteUpdateHint>.broadcast();
  final _partnerStatuses = StreamController<PartnerStatusHint>.broadcast();
  final _paymentStatuses = StreamController<PaymentStatusHint>.broadcast();
  final _callEvents = StreamController<Map<String, Object?>>.broadcast();
  final _chatMessages = StreamController<ChatMessageHint>.broadcast();
  final _rideUnassigned = StreamController<RideUnassignedHint>.broadcast();
  final _inboxEvents = StreamController<void>.broadcast();
  final _jobRequests = StreamController<void>.broadcast();
  final subscribed = <String>{};
  var connectCalls = 0;
  var disconnectCalls = 0;

  /// Tests set this true to exercise the socket-connected path (no poll).
  var connected = false;

  @override
  Stream<SnapshotHint> get snapshots => _snapshots.stream;

  @override
  Stream<DriverLocationHint> get driverLocations => _driverLocations.stream;

  @override
  Stream<RideOffersHint> get rideOffers => _rideOffers.stream;

  @override
  Stream<RouteUpdateHint> get routeUpdates => _routeUpdates.stream;

  @override
  Stream<PartnerStatusHint> get partnerStatuses => _partnerStatuses.stream;

  @override
  Stream<PaymentStatusHint> get paymentStatuses => _paymentStatuses.stream;

  @override
  Stream<RideUnassignedHint> get rideUnassigned => _rideUnassigned.stream;

  @override
  Stream<Map<String, Object?>> get callEvents => _callEvents.stream;

  @override
  Stream<ChatMessageHint> get chatMessages => _chatMessages.stream;

  @override
  Stream<void> get inboxEvents => _inboxEvents.stream;

  @override
  Stream<void> get jobRequests => _jobRequests.stream;

  @override
  Stream<void> get reconnects => _reconnects.stream;

  @override
  bool get isConnected => connected;

  @override
  Future<void> connect({required String accessToken}) async {
    connectCalls += 1;
  }

  @override
  Future<void> disconnect() async {
    disconnectCalls += 1;
    subscribed.clear();
    connected = false;
  }

  @override
  Future<void> subscribe(SnapshotRoom room) async {
    subscribed.add(room.name);
  }

  @override
  Future<void> unsubscribe(SnapshotRoom room) async {
    subscribed.remove(room.name);
  }

  void emitHint(SnapshotHint hint) => _snapshots.add(hint);

  void emitJobRequest() => _jobRequests.add(null);

  void emitReconnect() => _reconnects.add(null);

  void emitDriverLocation(DriverLocationHint hint) =>
      _driverLocations.add(hint);

  void emitRideOffers(RideOffersHint hint) => _rideOffers.add(hint);

  void emitRouteUpdate(RouteUpdateHint hint) => _routeUpdates.add(hint);

  void emitPartnerStatus(PartnerStatusHint hint) => _partnerStatuses.add(hint);

  void emitPaymentStatus(PaymentStatusHint hint) => _paymentStatuses.add(hint);

  void emitCall(Map<String, Object?> payload) => _callEvents.add(payload);

  void emitChatMessage(ChatMessageHint hint) => _chatMessages.add(hint);

  void emitRideUnassigned(RideUnassignedHint hint) => _rideUnassigned.add(hint);

  void emitInbox() => _inboxEvents.add(null);

  Future<void> dispose() async {
    await _routeUpdates.close();
    await _partnerStatuses.close();
    await _paymentStatuses.close();
    await _callEvents.close();
    await _chatMessages.close();
    await _rideUnassigned.close();
    await _rideOffers.close();
    await _snapshots.close();
    await _reconnects.close();
    await _driverLocations.close();
    await _inboxEvents.close();
  }
}
