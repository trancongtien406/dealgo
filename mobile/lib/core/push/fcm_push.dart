import 'dart:async';

import 'package:dio/dio.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';

import '../../features/voice/data/native/callkit_native_call_ui.dart';
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
  // Android: an incoming-call push rings the system call screen even when the
  // app is killed (iOS does this through PushKit in AppDelegate).
  try {
    await handleCallPushInBackground(
      Map<String, Object?>.of(message.data),
      title: message.notification?.title ?? _dataText(message, 'title'),
      body: message.notification?.body ?? _dataText(message, 'body'),
    );
  } catch (error) {
    if (kDebugMode) {
      debugPrint('FCM background call handling failed: $error');
    }
  }
}

/// `platform` for the iOS PushKit token; the server sends only incoming-call
/// pushes there (APNs VoIP), never FCM.
const voipPushPlatform = 'ios-voip';

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
  FcmPush({
    required this.dio,
    this.voipToken,
    this.voipTokenChanges,
    this.prepareCalls,
  });

  final Dio dio;

  /// iOS PushKit token source (CallKit); null on Android/web or until iOS has one.
  final Future<String?> Function()? voipToken;

  /// New PushKit token from iOS → uploaded again while signed in.
  final Stream<void>? voipTokenChanges;

  /// Runs once notifications are allowed (Android full-screen call permission).
  final Future<void> Function()? prepareCalls;
  StreamSubscription<void>? _voipChangeSub;
  String? _postedVoip;
  bool _callsPrepared = false;
  String? _accessToken;
  String? _registeredForAccessToken;
  StreamSubscription<String>? _tokenRefreshSub;

  StreamSubscription<RemoteMessage>? _openedSub;
  StreamSubscription<RemoteMessage>? _foregroundSub;

  bool get _firebaseReady => Firebase.apps.isNotEmpty;

  @override
  Future<void> listenForTaps(
    void Function(Map<String, Object?> data) onTap,
  ) async {
    if (!_firebaseReady || _openedSub != null) {
      return;
    }
    try {
      _openedSub = FirebaseMessaging.onMessageOpenedApp.listen(
        (message) => onTap(Map<String, Object?>.of(message.data)),
      );
      final initial = await FirebaseMessaging.instance.getInitialMessage();
      if (initial != null) {
        onTap(Map<String, Object?>.of(initial.data));
      }
    } catch (error) {
      if (kDebugMode) {
        debugPrint('FCM tap listener failed: $error');
      }
    }
  }

  @override
  Future<void> listenForeground(
    void Function(PushMessage message) onMessage,
  ) async {
    // iOS presents foreground pushes itself (alert: true) and routes the tap
    // through onMessageOpenedApp; only Android needs an in-app banner.
    if (!_firebaseReady ||
        _foregroundSub != null ||
        kIsWeb ||
        defaultTargetPlatform != TargetPlatform.android) {
      return;
    }
    try {
      _foregroundSub = FirebaseMessaging.onMessage.listen(
        (message) => onMessage(
          PushMessage(
            title: message.notification?.title ?? _dataText(message, 'title'),
            body: message.notification?.body ?? _dataText(message, 'body'),
            data: Map<String, Object?>.of(message.data),
          ),
        ),
      );
    } catch (error) {
      if (kDebugMode) {
        debugPrint('FCM foreground listener failed: $error');
      }
    }
  }

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
    _voipChangeSub ??= voipTokenChanges?.listen((_) {
      final current = _accessToken;
      if (current != null && current.isNotEmpty) {
        _registerVoipToken(current).ignore();
      }
    });

    if (_registeredForAccessToken == accessToken) {
      return;
    }

    try {
      // Prefer reading current settings first so token registration after the
      // launch prompt does not re-show the OS dialog.
      var settings = await FirebaseMessaging.instance.getNotificationSettings();
      if (settings.authorizationStatus == AuthorizationStatus.notDetermined) {
        settings = await FirebaseMessaging.instance.requestPermission(
          alert: true,
          badge: true,
          sound: true,
        );
      }
      if (kDebugMode) {
        debugPrint('FCM permission: ${settings.authorizationStatus}');
      }
      if (settings.authorizationStatus == AuthorizationStatus.denied) {
        return;
      }
      if (!_callsPrepared) {
        _callsPrepared = true;
        prepareCalls?.call().ignore();
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
      _postedVoip = null;
      await _registerVoipToken(accessToken);
    } on DioException catch (error) {
      final status = error.response?.statusCode;
      if (status == 404 || status == 501) {
        return;
      }
      throw apiExceptionFromDio(error);
    }
  }

  @override
  Future<void> unregister({required String accessToken}) async {
    _registeredForAccessToken = null;
    _accessToken = null;
    _postedVoip = null;
    if (!_firebaseReady || accessToken.isEmpty) {
      return;
    }
    try {
      final voip = await voipToken?.call();
      if (voip != null && voip.isNotEmpty) {
        await dio.delete<Object?>(
          ApiPaths.mePushTokens,
          data: {'token': voip},
          options: Options(headers: {'Authorization': 'Bearer $accessToken'}),
        );
      }
    } catch (error) {
      if (kDebugMode) {
        debugPrint('VoIP token unregister failed: $error');
      }
    }
    try {
      final token = await currentToken();
      if (token == null || token.isEmpty) {
        return;
      }
      await dio.delete<Object?>(
        ApiPaths.mePushTokens,
        data: {'token': token},
        options: Options(headers: {'Authorization': 'Bearer $accessToken'}),
      );
    } catch (error) {
      if (kDebugMode) {
        debugPrint('FCM unregister failed: $error');
      }
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
    String? platform,
  }) {
    return dio.post<Object?>(
      ApiPaths.mePushTokens,
      data: {'token': token, 'platform': platform ?? pushPlatformName()},
      options: Options(headers: {'Authorization': 'Bearer $accessToken'}),
    );
  }

  /// Best effort: without it iOS calls still ring via the normal alert push.
  Future<void> _registerVoipToken(String accessToken) async {
    try {
      final token = await voipToken?.call();
      if (token == null || token.isEmpty || token == _postedVoip) {
        return;
      }
      await _postToken(
        token: token,
        accessToken: accessToken,
        platform: voipPushPlatform,
      );
      _postedVoip = token;
    } catch (error) {
      if (kDebugMode) {
        debugPrint('VoIP token register failed: $error');
      }
    }
  }
}

/// Data-only pushes (Android incoming call) carry their copy in `data`.
String? _dataText(RemoteMessage message, String key) {
  final value = message.data[key];
  return value is String && value.trim().isNotEmpty ? value : null;
}
