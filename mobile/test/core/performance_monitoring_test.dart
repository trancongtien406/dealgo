import 'dart:typed_data';

import 'package:dealgo/core/network/perf_http_interceptor.dart';
import 'package:dealgo/core/observability/performance_monitoring.dart';
import 'package:dio/dio.dart';
import 'package:firebase_performance/firebase_performance.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('trace names are sanitized to what Firebase accepts', () {
    expect(traceName('app_bootstrap'), 'app_bootstrap');
    expect(traceName('voice call join'), 'voice_call_join');
    // No leading underscore: the native SDKs reject it.
    expect(traceName('3-retries'), 't_3-retries');
    expect(traceName('   '), isNull);
    // The console shows 32 characters, so longer names are cut.
    expect(traceName('a' * 40), 'a' * 32);
  });

  test('metric URLs keep the host and redact ids, query and fragment', () {
    expect(
      httpMetricUrl(
        Uri.parse('https://api.dealgo.vn/v1/rides/42/calls?q=token#x'),
      ),
      'https://api.dealgo.vn/v1/rides/:id/calls',
    );
    // Share tokens and long opaque ids are ids too.
    expect(
      httpMetricUrl(
        Uri.parse(
          'https://api.dealgo.vn/chia-se-chuyen/Zk3x9_aBcDeFgHiJkLmNoPqRs',
        ),
      ),
      'https://api.dealgo.vn/chia-se-chuyen/:id',
    );
    expect(
      httpMetricUrl(Uri.parse('http://localhost:3001/v1/calls/config')),
      'http://localhost:3001/v1/calls/config',
    );
    // Only http(s) can be reported.
    expect(httpMetricUrl(Uri.parse('ws://livekit.dealgo.vn/rtc')), isNull);
    expect(httpMetricUrl(Uri.parse('/v1/relative')), isNull);
  });

  test('methods map to the Firebase enum; unknown verbs are skipped', () {
    expect(httpMethod('GET'), HttpMethod.Get);
    expect(httpMethod('patch'), HttpMethod.Patch);
    expect(httpMethod('DELETE'), HttpMethod.Delete);
    expect(httpMethod('TRACE'), isNull);
  });

  test('collection is off in tests, so every helper is a no-op', () async {
    final perf = PerformanceMonitoring.instance;
    expect(perf.isEnabled, isFalse);
    // No Firebase app in `flutter test`: nothing may reach the platform channel.
    final trace = perf.startTrace('app_bootstrap');
    trace.putAttribute('flavor', 'dev');
    await trace.stop();
    expect(
      perf.startHttpMetric('GET', Uri.parse('https://api.dealgo.vn/v1')),
      isNull,
    );
    expect(await perf.measure('x', () async => 7), 7);
  });

  test(
    'interceptor leaves requests untouched when collection is off',
    () async {
      final dio = Dio(BaseOptions(baseUrl: 'https://api.dealgo.vn'));
      dio.interceptors.add(PerfHttpInterceptor());
      dio.httpClientAdapter = _NoopAdapter();
      final response = await dio.get<Map<String, dynamic>>('/v1/calls/config');
      expect(response.statusCode, 200);
      expect(response.requestOptions.extra, isEmpty);
    },
  );
}

class _NoopAdapter implements HttpClientAdapter {
  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async => ResponseBody.fromString(
    '{"ok":true}',
    200,
    headers: {
      Headers.contentTypeHeader: [Headers.jsonContentType],
      Headers.contentLengthHeader: ['11'],
    },
  );

  @override
  void close({bool force = false}) {}
}
