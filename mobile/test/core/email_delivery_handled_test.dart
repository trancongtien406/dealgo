import 'dart:convert';
import 'dart:typed_data';

import 'package:dealgo/core/network/dio_error_reporter.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

class _JsonAdapter implements HttpClientAdapter {
  _JsonAdapter(this.status, this.body);
  final int status;
  final Map<String, Object?> body;
  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async => ResponseBody.fromString(
    jsonEncode(body),
    status,
    headers: {
      Headers.contentTypeHeader: ['application/json'],
    },
  );
  @override
  void close({bool force = false}) {}
}

Future<(List<ApiFailureReport>, List<ApiFailureReport>)> _run(
  Map<String, Object?> body,
) async {
  final reports = <ApiFailureReport>[];
  final crumbs = <ApiFailureReport>[];
  final dio = Dio(BaseOptions(baseUrl: 'https://api.test'))
    ..httpClientAdapter = _JsonAdapter(503, body)
    ..interceptors.add(
      DioErrorReporter(sink: reports.add, breadcrumbSink: crumbs.add),
    );
  await expectLater(
    dio.post<dynamic>('/v1/auth/email/register'),
    throwsA(isA<DioException>()),
  );
  return (reports, crumbs);
}

void main() {
  test('EMAIL_DELIVERY_FAILED is a breadcrumb, not a Sentry error', () async {
    final (reports, crumbs) = await _run({
      'errorCode': 'EMAIL_DELIVERY_FAILED',
    });
    expect(reports, isEmpty);
    expect(crumbs.single.errorCode, 'EMAIL_DELIVERY_FAILED');
  });

  test('other 5xx are still reported', () async {
    final (reports, crumbs) = await _run({'errorCode': 'INTERNAL'});
    expect(reports, hasLength(1));
    expect(crumbs, isEmpty);
  });
}
