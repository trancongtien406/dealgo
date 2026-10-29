import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import 'api_paths.dart';

const _retryAttemptExtra = 'dealgo.startupRetryAttempt';

/// Retries the app's first idempotent GETs (sign-in options, food categories,
/// the ride list, the profile) when the network is not up yet at launch or on
/// resume. Only GETs on [paths], only connection-level failures, a small
/// backoff, never POST/PATCH/DELETE.
class StartupGetRetryInterceptor extends Interceptor {
  StartupGetRetryInterceptor(
    this._dio, {
    this.paths = defaultPaths,
    this.backoff = const [
      Duration(milliseconds: 400),
      Duration(milliseconds: 1200),
    ],
    Future<void> Function(Duration)? delay,
  }) : _delay = delay ?? Future<void>.delayed;

  static const defaultPaths = {
    ApiPaths.authMethods,
    ApiPaths.publicFoodCategories,
    ApiPaths.rides,
    ApiPaths.me,
  };

  final Dio _dio;
  final Set<String> paths;
  final List<Duration> backoff;
  final Future<void> Function(Duration) _delay;

  @visibleForTesting
  bool shouldRetry(DioException err) {
    final options = err.requestOptions;
    if (options.method.toUpperCase() != 'GET') return false;
    if (!paths.contains(options.uri.path) && !paths.contains(options.path)) {
      return false;
    }
    final attempt = (options.extra[_retryAttemptExtra] as int?) ?? 0;
    if (attempt >= backoff.length) return false;
    return switch (err.type) {
      DioExceptionType.connectionError ||
      DioExceptionType.connectionTimeout ||
      DioExceptionType.unknown => true,
      _ => false,
    };
  }

  @override
  Future<void> onError(
    DioException err,
    ErrorInterceptorHandler handler,
  ) async {
    if (!shouldRetry(err)) {
      handler.next(err);
      return;
    }
    final options = err.requestOptions;
    final attempt = (options.extra[_retryAttemptExtra] as int?) ?? 0;
    await _delay(backoff[attempt]);
    options.extra[_retryAttemptExtra] = attempt + 1;
    try {
      handler.resolve(await _dio.fetch<dynamic>(options));
    } on DioException catch (retryErr) {
      // The retried request already went through this interceptor (and the
      // reporter) itself; pass its final error on.
      handler.next(retryErr);
    }
  }
}
