import 'dart:async';

import 'package:dio/dio.dart';

import '../auth/token_store.dart';
import '../config/api_base_url.dart';
import 'api_envelope.dart';
import 'api_exception.dart';
import 'api_paths.dart';
import 'dio_mapper.dart';

const skipAuthRefreshExtra = 'dealgo.skipAuthRefresh';

typedef SessionRefreshed = Future<void> Function(StoredTokens tokens);
typedef SessionUnauthorized = Future<void> Function();

/// Shared DealGo API client. Feature Dio*Clients must receive this instance.
Dio createDealGoDio({
  String? baseUrl,
  required TokenStore tokenStore,
  required SessionRefreshed onSessionRefreshed,
  required SessionUnauthorized onUnauthorized,
}) {
  final dio = Dio(
    BaseOptions(
      baseUrl: normalizeBaseUrl(baseUrl ?? apiBaseUrl),
      connectTimeout: const Duration(seconds: 15),
      receiveTimeout: const Duration(seconds: 15),
      sendTimeout: const Duration(seconds: 15),
      headers: const {
        Headers.acceptHeader: Headers.jsonContentType,
        Headers.contentTypeHeader: Headers.jsonContentType,
      },
      responseType: ResponseType.json,
    ),
  );
  dio.interceptors.add(
    _DealGoAuthInterceptor(
      dio: dio,
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
    required this.tokenStore,
    required this.onSessionRefreshed,
    required this.onUnauthorized,
  });

  final Dio dio;
  final TokenStore tokenStore;
  final SessionRefreshed onSessionRefreshed;
  final SessionUnauthorized onUnauthorized;

  Future<StoredTokens?>? _refreshFlight;

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
      final response = await dio.fetch<Object?>(request);
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
      final response = await dio.post<Object?>(
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
          message: 'Phản hồi không hợp lệ',
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
