import 'dart:async';

import 'package:dealgo/core/network/dio_error_reporter.dart';
import 'package:dealgo/core/network/startup_get_retry.dart';
import 'package:dealgo/core/observability/crash_reporting.dart';
import 'package:dealgo/core/permissions/app_permission_service.dart';
import 'package:dealgo/features/voice/data/media/livekit_voice_media_engine.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:sentry_flutter/sentry_flutter.dart';

DioException _err(
  DioExceptionType type, {
  String method = 'GET',
  String path = '/v1/me',
  int? status,
}) {
  final options = RequestOptions(
    path: path,
    method: method,
    baseUrl: 'https://api.test',
  );
  return DioException(
    requestOptions: options,
    type: type,
    response: status == null
        ? null
        : Response(requestOptions: options, statusCode: status),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('DioErrorReporter', () {
    test('connection / unknown failures are breadcrumbs, not errors', () async {
      for (final type in [
        DioExceptionType.connectionError,
        DioExceptionType.unknown,
      ]) {
        final reports = <ApiFailureReport>[];
        final crumbs = <ApiFailureReport>[];
        final dio = Dio(BaseOptions(baseUrl: 'https://api.test'));
        dio.httpClientAdapter = _FailingAdapter(type);
        dio.interceptors.add(
          DioErrorReporter(sink: reports.add, breadcrumbSink: crumbs.add),
        );
        await expectLater(
          dio.get<dynamic>('/v1/x'),
          throwsA(isA<DioException>()),
        );
        expect(reports, isEmpty, reason: type.name);
        expect(crumbs, hasLength(1), reason: type.name);
      }
    });

    test('5xx and bad certificate are still reported', () {
      expect(
        DioErrorReporter.reportFor(
          _err(DioExceptionType.badResponse, status: 502),
        ),
        isNotNull,
      );
      expect(
        DioErrorReporter.reportFor(_err(DioExceptionType.badCertificate)),
        isNotNull,
      );
      expect(
        DioErrorReporter.reportFor(_err(DioExceptionType.unknown)),
        isNull,
      );
    });
  });

  group('StartupGetRetryInterceptor', () {
    final retry = StartupGetRetryInterceptor(Dio());
    test('retries only whitelisted idempotent GETs on network failures', () {
      expect(retry.shouldRetry(_err(DioExceptionType.connectionError)), isTrue);
      expect(
        retry.shouldRetry(
          _err(DioExceptionType.unknown, path: '/v1/auth/methods'),
        ),
        isTrue,
      );
      expect(
        retry.shouldRetry(
          _err(DioExceptionType.connectionError, method: 'POST'),
        ),
        isFalse,
      );
      expect(
        retry.shouldRetry(
          _err(DioExceptionType.connectionError, path: '/v1/rides/abc/accept'),
        ),
        isFalse,
      );
      expect(
        retry.shouldRetry(_err(DioExceptionType.badResponse, status: 500)),
        isFalse,
      );
    });

    test('gives up after the backoff list is used', () {
      final e = _err(DioExceptionType.connectionError);
      e.requestOptions.extra['dealgo.startupRetryAttempt'] = 2;
      expect(retry.shouldRetry(e), isFalse);
    });

    test('a retried GET that succeeds resolves without an error', () async {
      var calls = 0;
      final dio = Dio(BaseOptions(baseUrl: 'https://api.test'));
      dio.httpClientAdapter = _FlakyAdapter(() => ++calls);
      dio.interceptors.add(
        StartupGetRetryInterceptor(dio, delay: (_) async {}),
      );
      final res = await dio.get<dynamic>('/v1/me');
      expect(res.statusCode, 200);
      expect(calls, 2);
    });
  });

  group('audio session retry', () {
    test('-4100 retries exactly once after beforeRetry', () async {
      var attempts = 0;
      var prepared = 0;
      await runWithAudioSessionRetry(() async {
        attempts++;
        if (attempts == 1) throw Exception('AudioSessionException code -4100');
      }, beforeRetry: () async => prepared++);
      expect(attempts, 2);
      expect(prepared, 1);
    });

    test('other errors are not retried', () async {
      var attempts = 0;
      await expectLater(
        runWithAudioSessionRetry(() async {
          attempts++;
          throw StateError('bad token');
        }, beforeRetry: () async {}),
        throwsStateError,
      );
      expect(attempts, 1);
    });

    test(
      'audio-session recovery always includes a real settle delay',
      () async {
        final delays = <Duration>[];
        await waitForAudioSessionRecovery(
          foregroundTimeout: Duration.zero,
          settleDelay: const Duration(milliseconds: 500),
          delay: (duration) async => delays.add(duration),
        );
        expect(delays, [const Duration(milliseconds: 500)]);
      },
    );
  });

  test('background WebSocket closes are not sent to Sentry', () {
    final closed = SentryEvent(
      exceptions: [
        SentryException(type: 'WebSocketConnectionClosed', value: 'closed'),
      ],
    );
    final other = SentryEvent(
      exceptions: [SentryException(type: 'StateError', value: 'boom')],
    );
    expect(isExpectedTransportClose(closed), isTrue);
    expect(isExpectedTransportClose(other), isFalse);
  });

  test('ensurePhotos shares one in-flight OS prompt', () async {
    final service = AppPermissionService();
    final answer = Completer<PermissionStatus>();
    var prompts = 0;
    service.requestPhotos = () {
      prompts++;
      return answer.future;
    };
    final a = service.ensurePhotos();
    final b = service.ensurePhotos();
    answer.complete(PermissionStatus.granted);
    expect(await a, isTrue);
    expect(await b, isTrue);
    expect(prompts, 1);
    service.requestPhotos = () async {
      prompts++;
      return PermissionStatus.denied;
    };
    expect(await service.ensurePhotos(), isFalse);
    expect(prompts, 2);
  });
}

class _FlakyAdapter implements HttpClientAdapter {
  _FlakyAdapter(this.onCall);
  final int Function() onCall;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<List<int>>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    if (onCall() == 1) {
      throw DioException.connectionError(
        requestOptions: options,
        reason: 'offline',
      );
    }
    return ResponseBody.fromString(
      '{}',
      200,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

class _FailingAdapter implements HttpClientAdapter {
  _FailingAdapter(this.type);
  final DioExceptionType type;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<List<int>>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    throw DioException(requestOptions: options, type: type);
  }

  @override
  void close({bool force = false}) {}
}
