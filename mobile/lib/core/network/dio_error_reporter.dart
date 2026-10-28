import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import '../observability/crash_reporting.dart';

/// A server or client failure worth a crash report, without request data.
class ApiFailureReport implements Exception {
  const ApiFailureReport({
    required this.method,
    required this.path,
    required this.kind,
    this.status,
    this.errorCode,
    this.requestId,
  });

  final String method;

  /// Path with ids replaced by `:id` and no query ([redactPath]).
  final String path;
  final String kind;
  final int? status;
  final String? errorCode;
  final String? requestId;

  @override
  String toString() => [
    'API ${status ?? kind} $method $path',
    if (errorCode != null) errorCode,
    if (requestId != null) 'requestId=$requestId',
  ].join(' ');
}

typedef ApiFailureSink = void Function(ApiFailureReport report);

/// Reports 5xx responses and unexpected Dio failures to Sentry. 4xx answers
/// (business rules) and offline/timeouts (the user's network) are not bugs
/// and stay out. Never sends headers, bodies or query strings.
class DioErrorReporter extends Interceptor {
  DioErrorReporter({ApiFailureSink? sink}) : _sink = sink ?? _toSentry;

  final ApiFailureSink _sink;

  static void _toSentry(ApiFailureReport report) => reportHandledError(
    report,
    fingerprint: [
      'api',
      report.method,
      report.path,
      '${report.status ?? report.kind}',
    ],
  );

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    final report = reportFor(err);
    if (report != null) _sink(report);
    handler.next(err);
  }

  @visibleForTesting
  static ApiFailureReport? reportFor(DioException err) {
    final status = err.response?.statusCode;
    final reportable = switch (err.type) {
      DioExceptionType.badResponse => status != null && status >= 500,
      DioExceptionType.unknown || DioExceptionType.badCertificate => true,
      _ => false,
    };
    if (!reportable) return null;
    final body = err.response?.data;
    String? field(String key) =>
        body is Map && body[key] is String ? body[key] as String : null;
    return ApiFailureReport(
      method: err.requestOptions.method,
      path: redactPath(err.requestOptions.uri.path),
      kind: err.type.name,
      status: status,
      errorCode: field('errorCode'),
      requestId:
          field('requestId') ?? err.response?.headers.value('x-request-id'),
    );
  }
}
