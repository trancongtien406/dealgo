import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:socket_io_client/socket_io_client.dart' as io;

import '../config/api_base_url.dart';
import 'snapshot_realtime.dart';

/// Reads the current access token (token store) at handshake time.
typedef AccessTokenReader = Future<String?> Function();

/// Forces a session refresh and returns the new access token, or null when the
/// session cannot be refreshed (caller signs out).
typedef AccessTokenRefresher = Future<String?> Function();

/// Socket.IO client for `snapshot` hints (DG-API-RT-001).
///
/// Auth: every (re)connect reads the latest access token through an auth
/// callback, so a refreshed token is used after an API restart / transport
/// drop. When the server rejects the handshake (`error` UNAUTHORIZED followed
/// by a server-side disconnect, which socket.io never auto-retries) the client
/// refreshes the session once and reconnects.
///
/// Reconnect policy: every connect after the first re-subscribes known rooms
/// and emits [reconnects] once so feature Cubits/pages issue one REST GET.
class SocketSnapshotRealtime implements SnapshotRealtime {
  SocketSnapshotRealtime({
    String? baseUrl,
    this._readAccessToken,
    this._refreshAccessToken,
  }) : _baseUrl = normalizeBaseUrl(baseUrl ?? apiBaseUrl);

  /// Max consecutive refresh attempts without a successful connect.
  static const maxAuthRecoveries = 3;

  final String _baseUrl;
  final AccessTokenReader? _readAccessToken;
  final AccessTokenRefresher? _refreshAccessToken;
  final _snapshots = StreamController<SnapshotHint>.broadcast();
  final _reconnects = StreamController<void>.broadcast();
  final _driverLocations = StreamController<DriverLocationHint>.broadcast();
  final _rideOffers = StreamController<RideOffersHint>.broadcast();
  final _routeUpdates = StreamController<RouteUpdateHint>.broadcast();
  final _partnerStatuses = StreamController<PartnerStatusHint>.broadcast();
  final _callEvents = StreamController<Map<String, Object?>>.broadcast();
  final _chatMessages = StreamController<ChatMessageHint>.broadcast();
  final _rideUnassigned = StreamController<RideUnassignedHint>.broadcast();
  final _inboxEvents = StreamController<void>.broadcast();
  final _jobRequests = StreamController<void>.broadcast();

  /// Room → number of live consumers. QA M2 root cause: rooms were a plain
  /// set, so when the merchant order page closed its `store:{id}` binding it
  /// left the room the dashboard queue was still listening on, and new
  /// orders stopped arriving until the tab was reopened.
  final _rooms = <String, int>{};

  io.Socket? _socket;
  String? _token;
  String? _subject;
  bool _hasConnected = false;
  int _authRecoveries = 0;
  Future<void>? _recovery;
  Timer? _retryTimer;

  /// Delay before retrying a handshake when the refresh could not complete.
  @visibleForTesting
  static Duration retryDelay = const Duration(seconds: 5);

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
  bool get isConnected => _socket?.connected ?? false;

  /// Rooms that will be (re)subscribed on every connect.
  @visibleForTesting
  Set<String> get rooms => Set.unmodifiable(_rooms.keys);

  /// Token the next handshake sends: the token store wins over the token
  /// handed to [connect], so a refresh done by REST is picked up.
  @visibleForTesting
  Future<String?> currentToken() async {
    final reader = _readAccessToken;
    if (reader != null) {
      try {
        final stored = (await reader())?.trim() ?? '';
        if (stored.isNotEmpty) {
          if (jwtSubject(stored) == _subject || _subject == null) {
            _token = stored;
          }
        }
      } catch (_) {}
    }
    return _token;
  }

  @override
  Future<void> connect({required String accessToken}) async {
    final token = accessToken.trim();
    if (token.isEmpty) {
      return;
    }
    final subject = jwtSubject(token);
    final socket = _socket;
    if (socket != null && subject == _subject) {
      // Same actor (e.g. token refresh): keep the socket and rooms; the next
      // handshake reads the new token through the auth callback.
      _token = token;
      if (!socket.connected && !socket.active) {
        socket.connect();
      }
      return;
    }
    await disconnect();
    _token = token;
    _subject = subject;
    final options = io.OptionBuilder()
        .setTransports(['websocket'])
        .disableAutoConnect()
        // A fresh Manager per session: socket_io_client caches managers by
        // URL, so after sign-out/sign-in the cached one could keep the old
        // actor's handshake auth and the new session never gets its rooms.
        .enableForceNew()
        .setAuthFn((callback) {
          unawaited(currentToken().then((t) => callback({'token': t ?? ''})));
        })
        .enableReconnection()
        .build();
    final created = io.io(_baseUrl, options);
    created.onConnect((_) => onConnected());
    created.on('error', (dynamic raw) {
      if (isUnauthorizedError(raw)) {
        unawaited(recoverAuth());
      }
    });
    created.onConnectError((dynamic raw) {
      if (isUnauthorizedError(raw)) {
        unawaited(recoverAuth());
      }
    });
    created.onDisconnect((dynamic reason) {
      // Server-initiated disconnects are not retried by socket.io; an auth
      // rejection already triggered [recoverAuth] which reconnects.
      if (reason == 'io server disconnect' && _recovery == null) {
        unawaited(recoverAuth());
      }
    });
    created.on('snapshot', (dynamic raw) {
      final hint = _parseHint(raw);
      if (hint != null && !_snapshots.isClosed) {
        _snapshots.add(hint);
      }
    });
    created.on('driverLocation', (dynamic raw) {
      final hint = parseDriverLocationHint(raw);
      if (hint != null && !_driverLocations.isClosed) {
        _driverLocations.add(hint);
      }
    });
    created.on('rideOffers', (dynamic raw) {
      final hint = parseRideOffersHint(raw);
      if (hint != null && !_rideOffers.isClosed) {
        _rideOffers.add(hint);
      }
    });
    created.on('routeUpdated', (dynamic raw) {
      final hint = parseRouteUpdateHint(raw);
      if (hint != null && !_routeUpdates.isClosed) {
        _routeUpdates.add(hint);
      }
    });
    created.on('chatMessage', (dynamic raw) {
      final hint = parseChatMessageHint(raw);
      if (hint != null && !_chatMessages.isClosed) {
        _chatMessages.add(hint);
      }
    });
    created.on('inbox', (dynamic _) {
      if (!_inboxEvents.isClosed) {
        _inboxEvents.add(null);
      }
    });
    created.on('call', (dynamic raw) {
      if (raw is Map && !_callEvents.isClosed) {
        _callEvents.add(Map<String, Object?>.from(raw));
      }
    });
    created.on('rideUnassigned', (dynamic raw) {
      final hint = parseRideUnassignedHint(raw);
      if (hint != null && !_rideUnassigned.isClosed) {
        _rideUnassigned.add(hint);
      }
    });
    // New nearby job for a driver: the open job list re-GETs at once instead of
    // waiting for a manual refresh / app resume.
    for (final event in const ['rideRequest', 'foodRequest']) {
      created.on(event, (dynamic _) {
        if (!_jobRequests.isClosed) {
          _jobRequests.add(null);
        }
      });
    }
    created.on('partnerStatus', (dynamic raw) {
      final hint = parsePartnerStatusHint(raw);
      if (hint != null && !_partnerStatuses.isClosed) {
        _partnerStatuses.add(hint);
      }
    });
    _socket = created;
    created.connect();
  }

  /// Back in the foreground: iOS closes the WebSocket while suspended and
  /// socket.io's backoff may still be waiting, so reconnect now. The connect
  /// fires [reconnects], which re-GETs feeds (e.g. the driver job list) quietly.
  void resumeIfDisconnected() {
    final socket = _socket;
    if (socket != null && !socket.connected) {
      socket.connect();
    }
  }

  /// Handles a successful (re)connect: resubscribe, then one reconnect hint.
  @visibleForTesting
  void onConnected() {
    _authRecoveries = 0;
    _resubscribeAll();
    if (_hasConnected && !_reconnects.isClosed) {
      _reconnects.add(null);
    }
    _hasConnected = true;
  }

  /// Refreshes the session and reconnects (single flight, capped).
  @visibleForTesting
  Future<void> recoverAuth() {
    return _recovery ??= _recoverAuth().whenComplete(() => _recovery = null);
  }

  Future<void> _recoverAuth() async {
    if (_authRecoveries >= maxAuthRecoveries) {
      return;
    }
    _authRecoveries++;
    final refresher = _refreshAccessToken;
    String? next;
    if (refresher != null) {
      try {
        next = (await refresher())?.trim();
      } catch (_) {
        next = null;
      }
    }
    if (next == null || next.isEmpty) {
      // Either signed out (binder disconnects us) or the API is unreachable:
      // retry the handshake later; it re-reads the token store.
      _retryTimer?.cancel();
      _retryTimer = Timer(retryDelay, () {
        final socket = _socket;
        if (socket != null && !socket.connected) {
          socket.connect();
        }
      });
      return;
    }
    if (_subject != null && jwtSubject(next) != _subject) {
      return;
    }
    _token = next;
    final socket = _socket;
    if (socket == null) {
      return;
    }
    if (!socket.connected) {
      socket.connect();
    }
  }

  @override
  Future<void> disconnect() async {
    final socket = _socket;
    _socket = null;
    _token = null;
    _subject = null;
    _hasConnected = false;
    _authRecoveries = 0;
    _retryTimer?.cancel();
    _retryTimer = null;
    _rooms.clear();
    socket?.dispose();
  }

  @override
  Future<void> subscribe(SnapshotRoom room) async {
    _rooms.update(room.name, (n) => n + 1, ifAbsent: () => 1);
    final socket = _socket;
    if (socket == null || !socket.connected) {
      return;
    }
    socket.emitWithAck('subscribe', {'room': room.name}, ack: (_) {});
  }

  @override
  Future<void> unsubscribe(SnapshotRoom room) async {
    final left = (_rooms[room.name] ?? 0) - 1;
    if (left > 0) {
      _rooms[room.name] = left;
      return;
    }
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
    for (final room in _rooms.keys) {
      socket.emitWithAck('subscribe', {'room': room}, ack: (_) {});
    }
  }

  Future<void> dispose() async {
    await disconnect();
    await _snapshots.close();
    await _reconnects.close();
    await _driverLocations.close();
    await _rideOffers.close();
    await _routeUpdates.close();
    await _partnerStatuses.close();
    await _callEvents.close();
    await _chatMessages.close();
    await _rideUnassigned.close();
    await _inboxEvents.close();
    await _jobRequests.close();
  }
}

/// Parses a `rideOffers` payload; offers themselves are re-read via REST.
RideOffersHint? parseRideOffersHint(Object? raw) {
  if (raw is! Map) {
    return null;
  }
  final rideId = raw['rideId'];
  final revision = raw['revision'];
  if (rideId is! String || revision is! String) {
    return null;
  }
  final reason = raw['reason'];
  final status = raw['status'];
  return RideOffersHint(
    rideId: rideId,
    reason: reason is String ? reason : 'OFFER',
    status: status is String ? status : '',
    revision: revision,
  );
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
    storeId: map['storeId'] is String ? map['storeId'] as String : null,
  );
}

/// Parses a `driverLocation` payload `{aggregateType, aggregateId, lat, lng, at}`.
DriverLocationHint? parseDriverLocationHint(Object? raw) {
  if (raw is! Map) {
    return null;
  }
  final type = raw['aggregateType'];
  final id = raw['aggregateId'];
  final lat = raw['lat'];
  final lng = raw['lng'];
  final at = DateTime.tryParse('${raw['at']}');
  if (type is! String ||
      id is! String ||
      lat is! num ||
      lng is! num ||
      at == null) {
    return null;
  }
  return DriverLocationHint(
    aggregateType: type,
    aggregateId: id,
    lat: lat.toDouble(),
    lng: lng.toDouble(),
    at: at,
    heading: raw['heading'] is num ? (raw['heading'] as num).toDouble() : null,
    speedMps: raw['speedMps'] is num
        ? (raw['speedMps'] as num).toDouble()
        : null,
  );
}

/// True for the gateway's `{code: UNAUTHORIZED|...}` error payloads.
bool isUnauthorizedError(Object? raw) {
  if (raw is Map) {
    final code = '${raw['code'] ?? raw['message'] ?? ''}'.toUpperCase();
    return code.contains('UNAUTHORIZED') || code.contains('TOKEN');
  }
  final text = '$raw'.toUpperCase();
  return text.contains('UNAUTHORIZED');
}

/// `sub` claim of a JWT (no signature check; used only to tell actors apart).
String? jwtSubject(String token) {
  final parts = token.split('.');
  if (parts.length != 3) {
    return null;
  }
  try {
    final payload = jsonDecode(
      utf8.decode(base64Url.decode(base64Url.normalize(parts[1]))),
    );
    if (payload is Map && payload['sub'] is String) {
      return payload['sub'] as String;
    }
  } catch (_) {}
  return null;
}
