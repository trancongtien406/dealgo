import 'dart:async';

import 'package:dealgo/core/config/app_env.dart';
import 'package:dealgo/core/maps/create_map_port.dart';
import 'package:dealgo/core/maps/placeholder_map_port.dart';
import 'package:dealgo/core/maps/tile_map_port.dart';
import 'package:dealgo/core/maps/maps_client_config.dart';
import 'package:dio/dio.dart';
import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _StubAdapter implements HttpClientAdapter {
  _StubAdapter(this.body, {this.status = 200, this.gate});
  final String body;
  final int status;

  /// Holds the response until completed (a slow network).
  final Completer<void>? gate;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<List<int>>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    await gate?.future;
    return ResponseBody.fromString(
      body,
      status,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

Dio _dio(String body, {int status = 200, Completer<void>? gate}) =>
    Dio(BaseOptions(baseUrl: 'https://api.test'))
      ..httpClientAdapter = _StubAdapter(body, status: status, gate: gate);

const _adminToken = '{"success":true,"data":{"mapboxPublicToken":"pk.admin"}}';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    adminMapboxToken = '';
  });

  tearDown(() => adminMapboxToken = '');

  test('refresh applies the Admin token live and caches it', () async {
    await MapsClientConfig.refresh(_dio(_adminToken));
    expect(adminMapboxToken, 'pk.admin');
    adminMapboxToken = '';
    await MapsClientConfig.warmUp();
    expect(adminMapboxToken, 'pk.admin');
    expect(effectiveMapsApiKey, 'pk.admin');
    expect(effectiveMapTileUrl, mapboxStreetsTileUrl);
  });

  test('a cleared or non-public token removes the cache', () async {
    SharedPreferences.setMockInitialValues({
      'dealgo.mapboxPublicToken': 'pk.old',
    });
    await MapsClientConfig.refresh(
      _dio('{"success":true,"data":{"mapboxPublicToken":"sk.secret"}}'),
    );
    await MapsClientConfig.warmUp();
    expect(adminMapboxToken, isEmpty);
    expect(effectiveMapsApiKey, mapsApiKey);
  });

  test('a failed request keeps the cached token', () async {
    SharedPreferences.setMockInitialValues({
      'dealgo.mapboxPublicToken': 'pk.old',
    });
    await MapsClientConfig.refresh(_dio('oops', status: 500));
    await MapsClientConfig.warmUp();
    expect(adminMapboxToken, 'pk.old');
  });

  test(
    'fresh install: launch waits for the token before the first map',
    () async {
      await MapsClientConfig.resolveAtLaunch(_dio(_adminToken));
      expect(adminMapboxToken, 'pk.admin');
      expect(createMapPort(), isA<TileMapPort>());
    },
  );

  test(
    'cached token: launch does not wait; a newer token lands live',
    () async {
      SharedPreferences.setMockInitialValues({
        'dealgo.mapboxPublicToken': 'pk.old',
      });
      final gate = Completer<void>();
      final rebuilds = <String>[];
      void listener() => rebuilds.add(adminMapboxTokenListenable.value);
      adminMapboxTokenListenable.addListener(listener);
      addTearDown(() => adminMapboxTokenListenable.removeListener(listener));

      await MapsClientConfig.resolveAtLaunch(_dio(_adminToken, gate: gate));
      expect(adminMapboxToken, 'pk.old');
      gate.complete();
      await pumpEventQueue();
      expect(adminMapboxToken, 'pk.admin');
      expect(rebuilds, ['pk.old', 'pk.admin']);
    },
  );

  test('a slow API never holds the splash past launchWait', () {
    fakeAsync((async) {
      var done = false;
      final gate = Completer<void>();
      MapsClientConfig.resolveAtLaunch(_dio(_adminToken, gate: gate))
          .then((_) => done = true);
      async.elapse(MapsClientConfig.launchWait - const Duration(seconds: 1));
      expect(done, isFalse);
      async.elapse(const Duration(seconds: 2));
      expect(done, isTrue);
      expect(adminMapboxToken, isEmpty);
      gate.complete();
      async.elapse(const Duration(milliseconds: 10));
      expect(adminMapboxToken, 'pk.admin');
    });
  });

  test('MapPortSource swaps placeholder and tiles with the token', () {
    final source = MapPortSource();
    final placeholder = source.current;
    expect(placeholder, isA<PlaceholderMapPort>());
    expect(source.current, same(placeholder));
    adminMapboxToken = 'pk.admin';
    expect(source.current, isA<TileMapPort>());
    const fixed = PlaceholderMapPort();
    expect(MapPortSource(fixed).current, same(fixed));
  });
}
