import 'package:dealgo/core/auth/token_store.dart';
import 'package:dealgo/core/network/api_paths.dart';
import 'package:dealgo/core/network/dealgo_dio.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

ResponseBody _json(String body, int status) => ResponseBody.fromString(
  body,
  status,
  headers: {
    Headers.contentTypeHeader: [Headers.jsonContentType],
  },
);

const _unauthorized =
    '{"success":false,"statusCode":401,'
    '"message":"Authentication required","errorCode":"UNAUTHORIZED"}';

class _Adapter implements HttpClientAdapter {
  _Adapter(this.onFetch);
  final Future<ResponseBody> Function(RequestOptions options) onFetch;
  int refreshCalls = 0;

  @override
  void close({bool force = false}) {}

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<List<int>>? requestStream,
    Future<void>? cancelFuture,
  ) {
    if (options.path.contains(ApiPaths.sessionsRefresh)) refreshCalls++;
    return onFetch(options);
  }
}

String _bearer(RequestOptions o) => '${o.headers['Authorization']}';

Future<ResponseBody> _refreshOk(RequestOptions o, int n) async {
  await Future<void>.delayed(const Duration(milliseconds: 20));
  return _json(
    '{"success":true,"statusCode":200,"message":"OK","data":'
    '{"accessToken":"access-$n","refreshToken":"refresh-token-rotated-$n"}}',
    200,
  );
}

void main() {
  late MemoryTokenStore store;
  late int unauthorizedCalls;

  Dio build(_Adapter adapter) {
    final dio = createDealGoDio(
      baseUrl: 'https://api.test',
      tokenStore: store,
      onSessionRefreshed: (_) async {},
      onUnauthorized: () async => unauthorizedCalls++,
      enableLogging: false,
    );
    dio.httpClientAdapter = adapter;
    return dio;
  }

  setUp(() async {
    store = MemoryTokenStore();
    unauthorizedCalls = 0;
    await store.write(
      const StoredTokens(
        accessToken: 'expired',
        refreshToken: 'refresh-token-original-xx',
      ),
    );
  });

  test('retried request failing with 409 does not sign the user out', () async {
    late _Adapter adapter;
    adapter = _Adapter((o) async {
      if (o.path.contains(ApiPaths.sessionsRefresh)) {
        return _refreshOk(o, adapter.refreshCalls);
      }
      if (_bearer(o) == 'Bearer expired') return _json(_unauthorized, 401);
      return _json(
        '{"success":false,"statusCode":409,"message":"stale",'
        '"errorCode":"DRIVER_LOCATION_STALE"}',
        409,
      );
    });
    final dio = build(adapter);

    await expectLater(
      dio.get<Object?>('/v1/driver/rides/nearby'),
      throwsA(
        isA<DioException>().having(
          (e) => e.response?.statusCode,
          'status',
          409,
        ),
      ),
    );
    expect(unauthorizedCalls, 0);
    expect((await store.read())?.accessToken, 'access-1');
  });

  test('network failure during refresh keeps the session', () async {
    final adapter = _Adapter((o) async {
      if (o.path.contains(ApiPaths.sessionsRefresh)) {
        throw DioException.connectionError(
          requestOptions: o,
          reason: 'refused',
        );
      }
      return _json(_unauthorized, 401);
    });
    final dio = build(adapter);

    await expectLater(dio.get<Object?>('/v1/me'), throwsA(isA<DioException>()));
    expect(unauthorizedCalls, 0);
    expect(await store.read(), isNotNull);
  });

  test('rejected refresh token still signs out', () async {
    final adapter = _Adapter((o) async {
      if (o.path.contains(ApiPaths.sessionsRefresh)) {
        return _json(_unauthorized, 401);
      }
      return _json(_unauthorized, 401);
    });
    final dio = build(adapter);

    await expectLater(dio.get<Object?>('/v1/me'), throwsA(isA<DioException>()));
    expect(unauthorizedCalls, 1);
  });

  test('concurrent 401s on cold start refresh only once', () async {
    late _Adapter adapter;
    adapter = _Adapter((o) async {
      if (o.path.contains(ApiPaths.sessionsRefresh)) {
        return _refreshOk(o, adapter.refreshCalls);
      }
      if (_bearer(o) == 'Bearer expired') {
        await Future<void>.delayed(const Duration(milliseconds: 5));
        return _json(_unauthorized, 401);
      }
      return _json('{"success":true,"statusCode":200,"data":{}}', 200);
    });
    final dio = build(adapter);

    final results = await Future.wait([
      dio.get<Object?>('/v1/driver/active-job'),
      dio.get<Object?>('/v1/driver/history/summary'),
      dio.get<Object?>('/v1/me/presence/location'),
    ]);
    expect(results.map((r) => r.statusCode), everyElement(200));
    expect(adapter.refreshCalls, 1);
    expect(unauthorizedCalls, 0);
  });
}
