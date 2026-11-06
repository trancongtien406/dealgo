import 'dart:async';

import 'package:dio/dio.dart';

import '../observability/performance_monitoring.dart';

/// `options.extra` key holding the metric of the request in flight.
const _metricKey = 'dealgo.perf.httpMetric';

/// Reports every API request as a Firebase Performance HTTP metric.
///
/// `dart:io` sockets are invisible to the native SDKs, so without this the
/// console shows app start and custom traces but no network timings.
class PerfHttpInterceptor extends Interceptor {
  final _monitoring = PerformanceMonitoring.instance;

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    final metric = _monitoring.startHttpMetric(options.method, options.uri);
    if (metric != null) {
      options.extra[_metricKey] = metric;
    }
    handler.next(options);
  }

  @override
  void onResponse(
    Response<dynamic> response,
    ResponseInterceptorHandler handler,
  ) {
    final metric = response.requestOptions.extra[_metricKey];
    if (metric is PerfHttpMetric) {
      metric.respond(
        statusCode: response.statusCode,
        contentType: response.headers.value(Headers.contentTypeHeader),
        payloadSize: _size(response.headers.value(Headers.contentLengthHeader)),
      );
      unawaited(metric.finish());
    }
    handler.next(response);
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    final metric = err.requestOptions.extra[_metricKey];
    if (metric is PerfHttpMetric) {
      final status = err.response?.statusCode;
      metric.respond(
        statusCode: status,
        contentType: err.response?.headers.value(Headers.contentTypeHeader),
        payloadSize: _size(
          err.response?.headers.value(Headers.contentLengthHeader),
        ),
      );
      // No status code at all means the request never got a response: keep the
      // failure visible instead of reporting a fast, successful-looking call.
      metric.putAttribute('error', err.type.name);
      unawaited(metric.finish());
    }
    handler.next(err);
  }

  /// `content-length` is free; measuring the decoded body would copy it.
  static int? _size(String? raw) {
    if (raw == null) {
      return null;
    }
    final bytes = int.tryParse(raw);
    return bytes != null && bytes >= 0 ? bytes : null;
  }
}
