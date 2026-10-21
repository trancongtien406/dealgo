import 'dart:async';

import 'package:dio/dio.dart';

import '../auth/token_store.dart';
import '../config/api_base_url.dart';
import 'api_envelope.dart';
import 'api_exception.dart';
import 'api_paths.dart';
import 'dio_log.dart';
import 'dio_mapper.dart';

const skipAuthRefreshExtra = 'dealgo.skipAuthRefresh';

typedef SessionRefreshed = Future<void> Function(StoredTokens tokens);
typedef SessionUnauthorized = Future<void> Function();

BaseOptions _dealGoBaseOptions(String baseUrl) {
  return BaseOptions(
    baseUrl: normalizeBaseUrl(baseUrl),
    connectTimeout: const Duration(seconds: 15),
    receiveTimeout: const Duration(seconds: 15),
    sendTimeout: const Duration(seconds: 15),
    headers: const {
      Headers.acceptHeader: Headers.jsonContentType,
      Headers.contentTypeHeader: Headers.jsonContentType,
    },
    responseType: ResponseType.json,
  );
}

/// Shared DealGo API client. Feature Dio*Clients must receive this instance.
Dio createDealGoDio({
  String? baseUrl,
  required TokenStore tokenStore,
  required SessionRefreshed onSessionRefreshed,
  required SessionUnauthorized onUnauthorized,
  bool? enableLogging,
}) {
  final resolvedBase = normalizeBaseUrl(baseUrl ?? apiBaseUrl);
  final dio = Dio(_dealGoBaseOptions(resolvedBase));
  // Refresh/retry must not share the auth QueuedInterceptor: while onError is
  // awaiting, another request's onError is queued behind it and deadlocks.
  final refreshDio = Dio(_dealGoBaseOptions(resolvedBase));

  final logInterceptor = createDealGoLogInterceptor(enabled: enableLogging);
  if (logInterceptor != null) {
    dio.interceptors.add(logInterceptor);
    final refreshLog = createDealGoLogInterceptor(enabled: enableLogging);
    if (refreshLog != null) {
      refreshDio.interceptors.add(refreshLog);
    }
  }
  dio.interceptors.add(
    _DealGoAuthInterceptor(
      dio: dio,
      refreshDio: refreshDio,
      tokenStore: tokenStore,
      onSessionRefreshed: onSessionRefreshed,
      onUnauthorized: onUnauthorized,
    ),
  );
  return dio;
}

class _DealGoAuthInterceptor extends QueuedInterceptor {
  _DealGoAuthInterceptor({
    required this.dio,
    required this.refreshDio,
    required this.tokenStore,
    required this.onSessionRefreshed,
    required this.onUnauthorized,
  });

  final Dio dio;
  final Dio refreshDio;
  final TokenStore tokenStore;
  final SessionRefreshed onSessionRefreshed;
  final SessionUnauthorized onUnauthorized;

  Future<StoredTokens?>? _refreshFlight;

  void _syncRefreshClient() {
    refreshDio.options.baseUrl = dio.options.baseUrl;
    refreshDio.httpClientAdapter = dio.httpClientAdapter;
  }

  @override
  Future<void> onRequest(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) async {
    final existing = options.headers['Authorization'];
    if (existing is String && existing.isNotEmpty) {
      handler.next(options);
      return;
    }
    final stored = await tokenStore.read();
    final access = stored?.accessToken.trim() ?? '';
    if (access.isNotEmpty) {
      options.headers['Authorization'] = 'Bearer $access';
    }
    handler.next(options);
  }

  @override
  Future<void> onError(
    DioException err,
    ErrorInterceptorHandler handler,
  ) async {
    final status = err.response?.statusCode;
    final skip = err.requestOptions.extra[skipAuthRefreshExtra] == true;
    final alreadyRetried =
        err.requestOptions.extra['dealgo.authRetried'] == true;
    if (status != 401 || skip || alreadyRetried) {
      handler.next(err);
      return;
    }

    try {
      final next = await _refreshSingleFlight();
      if (next == null) {
        await onUnauthorized();
        handler.next(err);
        return;
      }
      final request = err.requestOptions;
      request.headers['Authorization'] = 'Bearer ${next.accessToken}';
      request.extra['dealgo.authRetried'] = true;
      _syncRefreshClient();
      final response = await refreshDio.fetch<Object?>(request);
      handler.resolve(response);
    } on DioException catch (refreshError) {
      await onUnauthorized();
      handler.next(refreshError);
    } catch (_) {
      await onUnauthorized();
      handler.next(err);
    }
  }

  Future<StoredTokens?> _refreshSingleFlight() {
    final inflight = _refreshFlight;
    if (inflight != null) {
      return inflight;
    }
    final future = _refreshOnce();
    _refreshFlight = future.whenComplete(() {
      _refreshFlight = null;
    });
    return _refreshFlight!;
  }

  Future<StoredTokens?> _refreshOnce() async {
    final stored = await tokenStore.read();
    final refresh = stored?.refreshToken.trim() ?? '';
    if (refresh.isEmpty) {
      return null;
    }
    try {
      _syncRefreshClient();
      final response = await refreshDio.post<Object?>(
        ApiPaths.sessionsRefresh,
        data: {'refreshToken': refresh},
        options: Options(extra: {skipAuthRefreshExtra: true}),
      );
      final data = requireSuccessData(response.data);
      final accessToken = data['accessToken'];
      final refreshToken = data['refreshToken'];
      if (accessToken is! String ||
          accessToken.isEmpty ||
          refreshToken is! String ||
          refreshToken.isEmpty) {
        throw const ApiException(
          statusCode: 200,
          message: 'Invalid response',
          errorCode: 'INVALID_RESPONSE',
        );
      }
      final next = StoredTokens(
        accessToken: accessToken,
        refreshToken: refreshToken,
      );
      await tokenStore.write(next);
      await onSessionRefreshed(next);
      return next;
    } on DioException catch (error) {
      throw apiExceptionFromDio(error);
    }
  }
}
