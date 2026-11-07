import '../../features/account_settings/presentation/session_device.dart';

import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart' show kReleaseMode;

import '../app_check/app_check_service.dart';
import '../app_gate/app_build_info.dart';
import '../auth/token_store.dart';
import '../config/api_base_url.dart';
import '../device/device_id_service.dart';
import 'api_envelope.dart';
import 'api_exception.dart';
import 'api_paths.dart';
import 'dio_error_reporter.dart';
import 'dio_log.dart';
import 'dio_mapper.dart';
import 'perf_http_interceptor.dart';
import 'startup_get_retry.dart';

const skipAuthRefreshExtra = 'dealgo.skipAuthRefresh';

typedef SessionRefreshed = Future<void> Function(StoredTokens tokens);
typedef SessionUnauthorized = Future<void> Function();

/// Lets non-HTTP transports (the realtime socket) force the same single-flight
/// refresh the HTTP interceptor uses. Wired by [createDealGoDio].
class SessionRefresher {
  Future<StoredTokens?> Function()? _impl;

  /// Refreshes the session; null when no refresh token is stored. Throws
  /// [ApiException] when the API rejects the refresh token.
  Future<StoredTokens?> refresh() async {
    final impl = _impl;
    return impl == null ? null : impl();
  }
}

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
  SessionRefresher? sessionRefresher,
  AppBuildInfo? appBuild,
  void Function()? onAppUpdateRequired,
  DeviceIdService? deviceIdService,
  AppCheckService? appCheckService,
}) {
  final resolvedBase = normalizeBaseUrl(baseUrl ?? apiBaseUrl);
  assertSecureApiBaseUrl(resolvedBase, isRelease: kReleaseMode);
  final dio = Dio(_dealGoBaseOptions(resolvedBase));
  // Refresh/retry uses a clean client without the auth interceptor so refresh
  // and retried requests never re-enter onError.
  final refreshDio = Dio(_dealGoBaseOptions(resolvedBase));

  if (appCheckService != null) {
    final appCheckInterceptor = AppCheckInterceptor(appCheckService);
    dio.interceptors.add(appCheckInterceptor);
    refreshDio.interceptors.add(appCheckInterceptor);
  }

  final deviceService = deviceIdService ?? DeviceIdService();
  final deviceInterceptor = DeviceIdInterceptor(deviceService);
  dio.interceptors.add(deviceInterceptor);
  refreshDio.interceptors.add(deviceInterceptor);

  final logInterceptor = createDealGoLogInterceptor(enabled: enableLogging);
  if (logInterceptor != null) {
    dio.interceptors.add(logInterceptor);
    final refreshLog = createDealGoLogInterceptor(enabled: enableLogging);
    if (refreshLog != null) {
      refreshDio.interceptors.add(refreshLog);
    }
  }
  final auth = _DealGoAuthInterceptor(
    dio: dio,
    refreshDio: refreshDio,
    tokenStore: tokenStore,
    onSessionRefreshed: onSessionRefreshed,
    onUnauthorized: onUnauthorized,
  );
  if (appBuild != null) {
    final gate = AppVersionInterceptor(
      appBuild: appBuild,
      onUpdateRequired: onAppUpdateRequired,
    );
    dio.interceptors.add(gate);
    refreshDio.interceptors.add(gate);
  }
  dio.interceptors.add(auth);
  // After auth: a 401 that refresh recovers never reaches the reporter.
  // Before the reporter: a launch GET that succeeds on retry is not an error.
  dio.interceptors.add(StartupGetRetryInterceptor(dio));
  dio.interceptors.add(DioErrorReporter());
  // Last on purpose: response/error callbacks run in reverse order, so the
  // metric is finished before the retry interceptor replays or swallows the
  // error. A metric that never stops leaks a platform object.
  final perf = PerfHttpInterceptor();
  dio.interceptors.add(perf);
  refreshDio.interceptors.add(perf);
  sessionRefresher?._impl = auth._refreshSingleFlight;
  return dio;
}

class _DealGoAuthInterceptor extends Interceptor {
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

  /// True when a 401 indicates an expired/revoked access token rather than a
  /// step-up re-authentication failure (`AUTH_CODE_INVALID`,
  /// `AUTH_PASSWORD_INVALID`, `AUTH_PASSKEY_INVALID`, `AUTH_CODE_EXPIRED`).
  bool _isSessionUnauthorized(DioException err) {
    final data = err.response?.data;
    if (data is Map) {
      final code = data['errorCode'];
      if (code is String && code.isNotEmpty && code != 'UNAUTHORIZED') {
        return false;
      }
    }
    return true;
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
    if (status != 401 ||
        skip ||
        alreadyRetried ||
        !_isSessionUnauthorized(err)) {
      handler.next(err);
      return;
    }

    final request = err.requestOptions;
    final StoredTokens? next;
    try {
      next = await _freshTokensFor(request);
    } on ApiException catch (refreshError) {
      // Only a definitive rejection of the refresh token ends the session.
      // Network / 5xx failures keep the user signed in so a cold start under
      // a slow or restarting API does not bounce them to the login screen.
      final code = refreshError.statusCode;
      if (code >= 400 && code < 500) {
        await onUnauthorized();
      }
      handler.next(err);
      return;
    } catch (_) {
      handler.next(err);
      return;
    }
    if (next == null) {
      await onUnauthorized();
      handler.next(err);
      return;
    }
    request.headers['Authorization'] = 'Bearer ${next.accessToken}';
    request.extra['dealgo.authRetried'] = true;
    try {
      _syncRefreshClient();
      final response = await refreshDio.fetch<Object?>(request);
      handler.resolve(response);
    } on DioException catch (retryError) {
      // The retried request failing for its own reasons (409, 404, 5xx,
      // timeout, or step-up re-auth failure) says nothing about the session;
      // only a second session 401 with a freshly refreshed token does.
      if (retryError.response?.statusCode == 401 &&
          _isSessionUnauthorized(retryError)) {
        await onUnauthorized();
      }
      handler.next(retryError);
    } catch (_) {
      handler.next(err);
    }
  }

  /// Tokens to retry [request] with. When another queued 401 already rotated
  /// the session, reuse the stored access token instead of refreshing again
  /// (each refresh rotates the refresh token).
  Future<StoredTokens?> _freshTokensFor(RequestOptions request) async {
    final sent = request.headers['Authorization'];
    final stored = await tokenStore.read();
    final storedAccess = stored?.accessToken.trim() ?? '';
    if (stored != null &&
        storedAccess.isNotEmpty &&
        sent is String &&
        sent != 'Bearer $storedAccess') {
      return stored;
    }
    return _refreshSingleFlight();
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

/// Socket auth recovery: refresh the session, sign out only when the API
/// definitively rejects it (4xx). Network failures return null so the socket
/// retries later instead of logging the user out during an API restart.
Future<String?> refreshRealtimeToken(
  SessionRefresher refresher,
  SessionUnauthorized onUnauthorized,
) async {
  try {
    final next = await refresher.refresh();
    if (next == null) {
      await onUnauthorized();
      return null;
    }
    return next.accessToken;
  } on ApiException catch (error) {
    final status = error.statusCode;
    if (status >= 400 && status < 500) {
      await onUnauthorized();
    }
    return null;
  } catch (_) {
    return null;
  }
}

/// t82u (DEC-PROD-089): tags every call with this build and maps the API's
/// `426 APP_UPDATE_REQUIRED` to the blocking "Cập nhật bắt buộc" screen.
class AppVersionInterceptor extends Interceptor {
  AppVersionInterceptor({required this.appBuild, this.onUpdateRequired});

  final AppBuildInfo appBuild;
  final void Function()? onUpdateRequired;

  static bool isUpdateRequired(DioException err) {
    final data = err.response?.data;
    final code = data is Map ? data['errorCode'] : null;
    return code == 'APP_UPDATE_REQUIRED' ||
        (err.response?.statusCode == 426 && code == null);
  }

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    options.headers.addAll(appBuild.headers);
    handler.next(options);
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    if (isUpdateRequired(err)) {
      onUpdateRequired?.call();
    }
    handler.next(err);
  }
}

/// Automatically appends the unique device identifier header `X-Device-Id` to all outgoing requests.
class DeviceIdInterceptor extends Interceptor {
  DeviceIdInterceptor(this.deviceIdService);

  final DeviceIdService deviceIdService;
  String? _cachedLabel;

  @override
  Future<void> onRequest(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) async {
    final deviceId = await deviceIdService.getDeviceId();
    if (deviceId.isNotEmpty) {
      options.headers['x-device-id'] = deviceId;
    }
    try {
      final label = _cachedLabel ??= await currentDeviceLabel();
      final safeLabel = toHeaderSafeAscii(label);
      if (safeLabel.isNotEmpty) {
        options.headers['x-device-label'] = safeLabel;
      }
    } catch (_) {}
    handler.next(options);
  }
}

/// Automatically appends Firebase App Check token to headers when available.
class AppCheckInterceptor extends Interceptor {
  AppCheckInterceptor(this.appCheckService);

  final AppCheckService appCheckService;

  @override
  Future<void> onRequest(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) async {
    final token = await appCheckService.getToken();
    if (token != null && token.isNotEmpty) {
      options.headers['x-firebase-appcheck'] = token;
    }
    handler.next(options);
  }
}
