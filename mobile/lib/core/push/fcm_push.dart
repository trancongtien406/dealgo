import 'dart:async';

import 'package:dio/dio.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';

import '../../firebase_options.dart';
import '../network/api_paths.dart';
import '../network/dio_mapper.dart';
import 'push_port.dart';

/// Top-level FCM background entry point (must be registered before [runApp]).
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  try {
    if (Firebase.apps.isEmpty) {
      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      );
    }
  } catch (error, stack) {
    if (kDebugMode) {
      debugPrint('FCM background handler: Firebase init failed: $error');
      debugPrint('$stack');
    }
  }
}

/// Lowercase platform labels for `POST /v1/me/push-tokens`.
String pushPlatformName() {
  if (kIsWeb) {
    return 'web';
  }
  switch (defaultTargetPlatform) {
    case TargetPlatform.iOS:
      return 'ios';
    case TargetPlatform.android:
      return 'android';
    case TargetPlatform.macOS:
      return 'macos';
    default:
      return defaultTargetPlatform.name.toLowerCase();
  }
}

/// Registers background + foreground presentation after Firebase init succeeds.
Future<void> configureFcmMessaging() async {
  if (Firebase.apps.isEmpty) {
    return;
  }
  FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);
  await FirebaseMessaging.instance.setForegroundNotificationPresentationOptions(
    alert: true,
    badge: true,
    sound: true,
  );
}

/// FCM-backed [PushPort]. Soft-fails when Firebase is not initialized so cold
/// start never crashes.
class FcmPush implements PushPort {
  FcmPush({required this.dio});

  final Dio dio;
  String? _accessToken;
  String? _registeredForAccessToken;
  StreamSubscription<String>? _tokenRefreshSub;

  bool get _firebaseReady => Firebase.apps.isNotEmpty;

  @override
  Future<String?> currentToken() async {
    if (!_firebaseReady) {
      return null;
    }
    try {
      return await FirebaseMessaging.instance.getToken();
    } catch (error) {
      if (kDebugMode) {
        debugPrint('FCM getToken failed: $error');
      }
      return null;
    }
  }

  @override
  Future<void> ensureRegistered({required String accessToken}) async {
    if (accessToken.isEmpty || !_firebaseReady) {
      return;
    }

    _accessToken = accessToken;
    await _ensureTokenRefreshListener();

    if (_registeredForAccessToken == accessToken) {
      return;
    }

    try {
      final settings = await FirebaseMessaging.instance.requestPermission(
        alert: true,
        badge: true,
        sound: true,
      );
      if (kDebugMode) {
        debugPrint('FCM permission: ${settings.authorizationStatus}');
      }
      if (settings.authorizationStatus == AuthorizationStatus.denied) {
        return;
      }
    } catch (error) {
      if (kDebugMode) {
        debugPrint('FCM requestPermission failed: $error');
      }
      return;
    }

    final token = await currentToken();
    if (token == null || token.isEmpty) {
      if (kDebugMode) {
        debugPrint('FCM getToken returned empty; check APNs / google-services');
      }
      return;
    }

    try {
      await _postToken(token: token, accessToken: accessToken);
      _registeredForAccessToken = accessToken;
    } on DioException catch (error) {
      final status = error.response?.statusCode;
      if (status == 404 || status == 501) {
        return;
      }
      throw apiExceptionFromDio(error);
    }
  }

  Future<void> _ensureTokenRefreshListener() async {
    if (_tokenRefreshSub != null || !_firebaseReady) {
      return;
    }
    _tokenRefreshSub = FirebaseMessaging.instance.onTokenRefresh.listen(
      (token) async {
        final accessToken = _accessToken;
        if (accessToken == null || accessToken.isEmpty || token.isEmpty) {
          return;
        }
        try {
          await _postToken(token: token, accessToken: accessToken);
          _registeredForAccessToken = accessToken;
        } catch (error) {
          if (kDebugMode) {
            debugPrint('FCM token refresh register failed: $error');
          }
        }
      },
      onError: (Object error) {
        if (kDebugMode) {
          debugPrint('FCM onTokenRefresh error: $error');
        }
      },
    );
  }

  Future<void> _postToken({
    required String token,
    required String accessToken,
  }) {
    return dio.post<Object?>(
      ApiPaths.mePushTokens,
      data: {'token': token, 'platform': pushPlatformName()},
      options: Options(headers: {'Authorization': 'Bearer $accessToken'}),
    );
  }
}
