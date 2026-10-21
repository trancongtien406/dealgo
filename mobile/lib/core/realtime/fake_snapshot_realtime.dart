import 'dart:async';

import 'snapshot_realtime.dart';

/// No-op realtime used for mock/demo and widget tests.
class FakeSnapshotRealtime implements SnapshotRealtime {
  final _snapshots = StreamController<SnapshotHint>.broadcast();
  final _reconnects = StreamController<void>.broadcast();
  final subscribed = <String>{};
  var connectCalls = 0;
  var disconnectCalls = 0;

  /// Tests set this true to exercise the socket-connected path (no poll).
  var connected = false;

  @override
  Stream<SnapshotHint> get snapshots => _snapshots.stream;

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

  void emitReconnect() => _reconnects.add(null);

  Future<void> dispose() async {
    await _snapshots.close();
    await _reconnects.close();
  }
}
