import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:sentry_flutter/sentry_flutter.dart';

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
  DioErrorReporter({ApiFailureSink? sink, ApiFailureSink? breadcrumbSink})
    : _sink = sink ?? _toSentry,
      _breadcrumbSink = breadcrumbSink ?? _toBreadcrumb;

  final ApiFailureSink _sink;
  final ApiFailureSink _breadcrumbSink;

  /// Connection drops / unknown socket errors are the user's network (or iOS
  /// suspending the app), not bugs: kept as context on later events only.
  static void _toBreadcrumb(ApiFailureReport report) => unawaited(
    Sentry.addBreadcrumb(
      Breadcrumb(
        category: 'api.network',
        level: SentryLevel.warning,
        message: '${report.kind} ${report.method} ${report.path}',
      ),
    ),
  );

  static void _toSentry(ApiFailureReport report) => reportHandledError(
    report,
    fingerprint: [
      'api',
      report.method,
      report.path,
      '${report.status ?? report.kind}',
    ],
  );

  /// 5xx codes the app already explains to the user (with a retry) and the
  /// backend reports with the real cause: breadcrumb only, no duplicate event.
  static const handledErrorCodes = {'EMAIL_DELIVERY_FAILED'};

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    final report = reportFor(err);
    if (report != null && handledErrorCodes.contains(report.errorCode)) {
      _breadcrumbSink(report);
    } else if (report != null) {
      _sink(report);
    } else if (isNetworkFailure(err)) {
      _breadcrumbSink(_build(err));
    }
    handler.next(err);
  }

  @visibleForTesting
  static ApiFailureReport? reportFor(DioException err) {
    final status = err.response?.statusCode;
    final reportable = switch (err.type) {
      DioExceptionType.badResponse => status != null && status >= 500,
      DioExceptionType.badCertificate => true,
      _ => false,
    };
    if (!reportable) return null;
    return _build(err);
  }

  @visibleForTesting
  static bool isNetworkFailure(DioException err) => switch (err.type) {
    DioExceptionType.connectionError || DioExceptionType.unknown => true,
    _ => false,
  };

  static ApiFailureReport _build(DioException err) {
    final status = err.response?.statusCode;
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
