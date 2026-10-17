import 'dart:async';

import 'package:socket_io_client/socket_io_client.dart' as io;

import '../config/api_base_url.dart';
import 'snapshot_realtime.dart';

/// Socket.IO client for `snapshot` hints (DG-API-RT-001).
///
/// Reconnect policy: after reconnect the client re-subscribes known rooms and
/// emits [reconnects] so feature Cubits/pages issue an authoritative REST GET.
class SocketSnapshotRealtime implements SnapshotRealtime {
  SocketSnapshotRealtime({String? baseUrl})
    : _baseUrl = normalizeBaseUrl(baseUrl ?? apiBaseUrl);

  final String _baseUrl;
  final _snapshots = StreamController<SnapshotHint>.broadcast();
  final _reconnects = StreamController<void>.broadcast();
  final _rooms = <String>{};

  io.Socket? _socket;
  String? _token;

  @override
  Stream<SnapshotHint> get snapshots => _snapshots.stream;

  @override
  Stream<void> get reconnects => _reconnects.stream;

  @override
  Future<void> connect({required String accessToken}) async {
    final token = accessToken.trim();
    if (token.isEmpty) {
      return;
    }
    if (_socket != null && _token == token && _socket!.connected) {
      return;
    }
    await disconnect();
    _token = token;
    final socket = io.io(
      _baseUrl,
      io.OptionBuilder()
          .setTransports(['websocket'])
          .disableAutoConnect()
          .setAuth({'token': token})
          .setExtraHeaders({'Authorization': 'Bearer $token'})
          .enableReconnection()
          .build(),
    );
    socket.onConnect((_) {
      _resubscribeAll();
    });
    socket.onReconnect((_) {
      _resubscribeAll();
      if (!_reconnects.isClosed) {
        _reconnects.add(null);
      }
    });
    socket.on('snapshot', (dynamic raw) {
      final hint = _parseHint(raw);
      if (hint != null && !_snapshots.isClosed) {
        _snapshots.add(hint);
      }
    });
    _socket = socket;
    socket.connect();
  }

  @override
  Future<void> disconnect() async {
    final socket = _socket;
    _socket = null;
    _token = null;
    _rooms.clear();
    socket?.dispose();
  }

  @override
  Future<void> subscribe(SnapshotRoom room) async {
    _rooms.add(room.name);
    final socket = _socket;
    if (socket == null || !socket.connected) {
      return;
    }
    socket.emitWithAck('subscribe', {'room': room.name}, ack: (_) {});
  }

  @override
  Future<void> unsubscribe(SnapshotRoom room) async {
    _rooms.remove(room.name);
    final socket = _socket;
    if (socket == null || !socket.connected) {
      return;
    }
    socket.emitWithAck('unsubscribe', {'room': room.name}, ack: (_) {});
  }

  void _resubscribeAll() {
    final socket = _socket;
    if (socket == null || !socket.connected) {
      return;
    }
    for (final room in _rooms) {
      socket.emitWithAck('subscribe', {'room': room}, ack: (_) {});
    }
  }

  Future<void> dispose() async {
    await disconnect();
    await _snapshots.close();
    await _reconnects.close();
  }
}

SnapshotHint? _parseHint(Object? raw) {
  if (raw is! Map) {
    return null;
  }
  final map = <String, Object?>{};
  raw.forEach((key, value) {
    map[key.toString()] = value;
  });
  final aggregateType = map['aggregateType'];
  final aggregateId = map['aggregateId'];
  final status = map['status'];
  final revision = map['revision'];
  final occurredAt = map['occurredAt'];
  if (aggregateType is! String ||
      aggregateId is! String ||
      status is! String ||
      revision is! String ||
      occurredAt is! String) {
    return null;
  }
  return SnapshotHint(
    eventType: map['eventType'] as String?,
    aggregateType: aggregateType,
    aggregateId: aggregateId,
    status: status,
    revision: revision,
    occurredAt: occurredAt,
  );
}
