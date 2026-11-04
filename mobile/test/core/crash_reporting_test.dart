import 'package:dealgo/core/network/dio_error_reporter.dart';
import 'package:dealgo/core/observability/crash_reporting.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sentry_flutter/sentry_flutter.dart';

void main() {
  test('crash reporting is off without a DSN', () {
    expect(isCrashReportingEnabled(''), isFalse);
    expect(isCrashReportingEnabled('  '), isFalse);
    expect(isCrashReportingEnabled('https://k@o1.ingest.sentry.io/1'), isTrue);
    // flutter test has no flavor and is not a release build.
    expect(isCrashReportingEnabled(), isFalse);
    expect(sentryEnvironment, 'dev');
  });

  test('flavored builds default to the public mobile DSN', () {
    expect(Uri.parse(dealGoMobileSentryDsn).path, '/4512373234597968');
  });

  test('runs the app directly when disabled', () async {
    var ran = false;
    await runWithCrashReporting(() async => ran = true);
    expect(ran, isTrue);
  });

  test('clamps the traces sample rate', () {
    expect(parseTracesSampleRate('0.25'), 0.25);
    expect(parseTracesSampleRate('2'), 0);
    expect(parseTracesSampleRate('x'), 0);
  });

  test('paths lose ids, tokens and queries', () {
    expect(
      redactPath(
        '/customer/ride/tracking/3f2b6c1e-8d2a-4e7b-9c1d-1a2b3c4d5e6f',
      ),
      '/customer/ride/tracking/:id',
    );
    expect(
      redactPath('/v1/food/orders/42/items?q=nha'),
      '/v1/food/orders/:id/items',
    );
    expect(
      redactPath('/chia-se-chuyen/Zk3x9_aBcDeFgHiJkLmNoPqRs'),
      '/chia-se-chuyen/:id',
    );
    expect(redactPath('/customer/ride/safety'), '/customer/ride/safety');
  });

  test('events keep only the user id and no request or query', () {
    final event = SentryEvent(
      user: SentryUser(id: 'u-1', email: 'a@b.c', name: 'An'),
      request: SentryRequest(
        url: 'https://x/y',
        headers: {'Authorization': 'B'},
      ),
      exceptions: [
        SentryException(
          type: 'DioException',
          value: 'GET https://api.x/v1/places?q=12 Le Loi failed',
        ),
      ],
    );
    final out = scrubEvent(event);
    expect(out.user!.id, 'u-1');
    expect(out.user!.email, isNull);
    expect(out.user!.name, isNull);
    expect(out.request, isNull);
    expect(
      out.exceptions!.single.value,
      'GET https://api.x/v1/places Le Loi failed',
    );
  });

  group('DioErrorReporter', () {
    DioException fail(DioExceptionType type, {int? status, Object? body}) {
      final options = RequestOptions(
        path: 'https://api.x/v1/rides/3f2b6c1e-8d2a-4e7b-9c1d-1a2b3c4d5e6f/offers?token=s',
        method: 'POST',
        headers: {'Authorization': 'Bearer secret'},
        data: {'fare': 1},
      );
      return DioException(
        requestOptions: options,
        type: type,
        response: status == null
            ? null
            : Response(requestOptions: options, statusCode: status, data: body),
      );
    }

    test('reports 5xx without request data', () {
      final report = DioErrorReporter.reportFor(
        fail(
          DioExceptionType.badResponse,
          status: 503,
          body: {'errorCode': 'X', 'requestId': 'r-1', 'message': 'boom'},
        ),
      )!;
      expect(
        report.toString(),
        'API 503 POST /v1/rides/:id/offers X requestId=r-1',
      );
      expect(report.toString(), isNot(contains('secret')));
      expect(report.toString(), isNot(contains('token')));
    });

    test('reports a bad certificate; unknown socket errors are network', () {
      final report = DioErrorReporter.reportFor(
        fail(DioExceptionType.badCertificate),
      )!;
      expect(report.kind, 'badCertificate');
      expect(report.status, isNull);
      expect(
        DioErrorReporter.reportFor(fail(DioExceptionType.unknown)),
        isNull,
      );
    });

    test('skips 4xx answers and the user network', () {
      for (final err in [
        fail(DioExceptionType.badResponse, status: 409),
        fail(DioExceptionType.badResponse, status: 401),
        fail(DioExceptionType.connectionError),
        fail(DioExceptionType.connectionTimeout),
        fail(DioExceptionType.receiveTimeout),
        fail(DioExceptionType.cancel),
      ]) {
        expect(DioErrorReporter.reportFor(err), isNull, reason: '${err.type}');
      }
    });

    test(
      'the interceptor hands reports to its sink and passes the error on',
      () async {
        final reports = <ApiFailureReport>[];
        final dio = Dio()
          ..httpClientAdapter = _StatusAdapter(500)
          ..interceptors.add(DioErrorReporter(sink: reports.add));
        await expectLater(
          dio.get<Object?>('https://api.x/v1/me'),
          throwsA(isA<DioException>()),
        );
        expect(reports.single.path, '/v1/me');
        expect(reports.single.status, 500);
      },
    );
  });
}

class _StatusAdapter implements HttpClientAdapter {
  _StatusAdapter(this.status);
  final int status;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<List<int>>? requestStream,
    Future<void>? cancelFuture,
  ) async => ResponseBody.fromString(
    '{"success":false}',
    status,
    headers: {
      Headers.contentTypeHeader: [Headers.jsonContentType],
    },
  );

  @override
  void close({bool force = false}) {}
}
