import 'dart:convert';

import 'package:dealgo/core/auth/token_store.dart';
import 'package:dealgo/core/network/api_exception.dart';
import 'package:dealgo/core/network/dealgo_dio.dart';
import 'package:dealgo/core/realtime/snapshot_realtime.dart';
import 'package:dealgo/core/realtime/socket_snapshot_realtime.dart';
import 'package:flutter_test/flutter_test.dart';

String jwt(String sub, {int n = 0}) {
  String b(Object o) =>
      base64Url.encode(utf8.encode(jsonEncode(o))).replaceAll('=', '');
  return '${b({'alg': 'HS256'})}.${b({'sub': sub, 'n': n})}.sig';
}

/// Stale-token fix: handshake reads the latest token, UNAUTHORIZED refreshes
/// once and reconnects, reconnect → one REST snapshot hint, logout/login resets.
void main() {
  // Unreachable port: sockets are created but never connect.
  const dead = 'http://127.0.0.1:1';

  test('jwtSubject / isUnauthorizedError', () {
    expect(jwtSubject(jwt('u1')), 'u1');
    expect(jwtSubject('garbage'), isNull);
    expect(
      isUnauthorizedError({'code': 'UNAUTHORIZED', 'message': 'x'}),
      isTrue,
    );
    expect(isUnauthorizedError({'code': 'TOKEN_EXPIRED'}), isTrue);
    expect(isUnauthorizedError('websocket error'), isFalse);
  });

  test('handshake token comes from the token store (refreshed by REST), not the stale one', () async {
    var stored = jwt('u1', n: 1);
    final rt = SocketSnapshotRealtime(
      baseUrl: dead,
      readAccessToken: () async => stored,
    );
    await rt.connect(accessToken: jwt('u1', n: 1));
    stored = jwt('u1', n: 2);
    expect(await rt.currentToken(), jwt('u1', n: 2));
    // A different actor's token in the store is never sent on this socket.
    stored = jwt('u2');
    expect(await rt.currentToken(), jwt('u1', n: 2));
    await rt.dispose();
  });

  test('token refresh for the same actor keeps the socket and rooms', () async {
    final rt = SocketSnapshotRealtime(baseUrl: dead);
    await rt.connect(accessToken: jwt('u1', n: 1));
    await rt.subscribe(const RideSnapshotRoom('r1'));
    await rt.connect(accessToken: jwt('u1', n: 2));
    expect(rt.rooms, {'ride:r1'});
    expect(await rt.currentToken(), jwt('u1', n: 2));
    await rt.dispose();
  });

  test(
    'logout/login (another actor) resets the socket, rooms and token',
    () async {
      final rt = SocketSnapshotRealtime(baseUrl: dead);
      await rt.connect(accessToken: jwt('driver-a'));
      await rt.subscribe(const RideSnapshotRoom('a'));
      await rt.disconnect();
      await rt.connect(accessToken: jwt('driver-b'));
      expect(rt.rooms, isEmpty);
      expect(await rt.currentToken(), jwt('driver-b'));
      await rt.dispose();
    },
  );

  test(
    'UNAUTHORIZED → single-flight refresh, capped; new token used',
    () async {
      var calls = 0;
      final rt = SocketSnapshotRealtime(
        baseUrl: dead,
        refreshAccessToken: () async {
          calls++;
          return jwt('u1', n: 9);
        },
      );
      await rt.connect(accessToken: jwt('u1'));
      await Future.wait([rt.recoverAuth(), rt.recoverAuth()]);
      expect(calls, 1);
      expect(await rt.currentToken(), jwt('u1', n: 9));
      for (var i = 0; i < 5; i++) {
        await rt.recoverAuth();
      }
      expect(calls, SocketSnapshotRealtime.maxAuthRecoveries);
      rt.onConnected(); // success resets the budget
      await rt.recoverAuth();
      expect(calls, SocketSnapshotRealtime.maxAuthRecoveries + 1);
      await rt.dispose();
    },
  );

  test(
    'first connect: no reconnect hint; later connects: exactly one each',
    () async {
      final rt = SocketSnapshotRealtime(baseUrl: dead);
      var hints = 0;
      final sub = rt.reconnects.listen((_) => hints++);
      await rt.connect(accessToken: jwt('u1'));
      rt.onConnected();
      await Future<void>.delayed(Duration.zero);
      expect(hints, 0);
      rt.onConnected();
      await Future<void>.delayed(Duration.zero);
      expect(hints, 1);
      await sub.cancel();
      await rt.dispose();
    },
  );

  group('refreshRealtimeToken', () {
    test('signs out only on a 4xx refresh rejection', () async {
      var signOuts = 0;
      Future<void> out() async => signOuts++;
      final ok = _Refresher(
        () async => const StoredTokens(accessToken: 'a2', refreshToken: 'r2'),
      );
      expect(await refreshRealtimeToken(ok, out), 'a2');
      final rejected = _Refresher(
        () async => throw const ApiException(
          statusCode: 401,
          message: 'x',
          errorCode: 'X',
        ),
      );
      expect(await refreshRealtimeToken(rejected, out), isNull);
      expect(signOuts, 1);
      final down = _Refresher(
        () async => throw const ApiException(
          statusCode: 503,
          message: 'x',
          errorCode: 'X',
        ),
      );
      expect(await refreshRealtimeToken(down, out), isNull);
      expect(signOuts, 1, reason: 'API restart must not log the user out');
    });
  });
}

class _Refresher extends SessionRefresher {
  _Refresher(this._fn);
  final Future<StoredTokens?> Function() _fn;
  @override
  Future<StoredTokens?> refresh() => _fn();
}
