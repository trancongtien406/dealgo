import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_callkit_incoming/entities/entities.dart';
import 'package:flutter_callkit_incoming/flutter_callkit_incoming.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../domain/ports/native_call_ui.dart';
import '../../../../core/auth/token_store.dart';

/// [NativeCallUi] on flutter_callkit_incoming: CallKit on iOS, a self-managed
/// ConnectionService (Telecom) call with a full-screen incoming UI on Android.
/// Every platform error is swallowed: the in-app call screen still works.
class CallkitNativeCallUi implements NativeCallUi {
  CallkitNativeCallUi();

  @override
  Stream<NativeCallAction> get actions => FlutterCallkitIncoming.onEvent
      .map(_toAction)
      .where((action) => action != null)
      .cast<NativeCallAction>()
      .handleError((Object error) => debugPrint('callkit events: $error'));

  @override
  Future<void> showIncoming(NativeIncomingCall call) =>
      _guard(() => FlutterCallkitIncoming.showCallkitIncoming(paramsFor(call)));

  @override
  Future<void> dismiss(String callId) =>
      _guard(() => FlutterCallkitIncoming.endCall(callId));

  @override
  Future<void> dismissOthers(String? keepCallId) async {
    if (kIsWeb) {
      return;
    }
    try {
      final calls = await FlutterCallkitIncoming.activeCalls();
      for (final call in calls) {
        if (!_sameCallId(call.id, keepCallId)) {
          await FlutterCallkitIncoming.endCall(call.id);
        }
      }
    } catch (error) {
      debugPrint('callkit activeCalls: $error');
    }
  }

  @override
  Future<void> setConnected(String callId) =>
      _guard(() => FlutterCallkitIncoming.setCallConnected(callId));

  @override
  Future<List<NativeCallAction>> acceptedOnLaunch() async {
    try {
      final calls = await FlutterCallkitIncoming.activeCalls();
      return [
        for (final call in calls)
          if (call.isAccepted)
            NativeCallAction(
              NativeCallActionType.accepted,
              call.id,
              _extra(call.extra),
            ),
      ];
    } catch (error) {
      debugPrint('callkit activeCalls: $error');
      return const [];
    }
  }

  @override
  Future<String?> voipPushToken() async {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.iOS) {
      return null;
    }
    try {
      final token = await FlutterCallkitIncoming.getDevicePushTokenVoIP();
      return token is String && token.isNotEmpty ? token : null;
    } catch (error) {
      debugPrint('callkit voip token: $error');
      return null;
    }
  }

  @override
  Stream<void> get voipTokenChanges => FlutterCallkitIncoming.onEvent
      .where((event) => event is CallEventActionDidUpdateDevicePushTokenVoip)
      .map<void>((_) {})
      .handleError((Object error) => debugPrint('callkit voip events: $error'));

  /// Set once the full-screen call permission screen was shown.
  static const fullScreenAskedKey = 'voice.fullScreenCallsAsked';

  @override
  Future<void> ensureFullScreenCalls() async {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) {
      return;
    }
    try {
      if (await FlutterCallkitIncoming.canUseFullScreenIntent()) {
        return;
      }
      final prefs = await SharedPreferences.getInstance();
      if (prefs.getBool(fullScreenAskedKey) ?? false) {
        return;
      }
      await prefs.setBool(fullScreenAskedKey, true);
      await FlutterCallkitIncoming.requestFullIntentPermission();
    } catch (error) {
      debugPrint('callkit full-screen permission: $error');
    }
  }

  @override
  Future<bool> isRinging(String callId) async {
    if (kIsWeb) {
      return false;
    }
    try {
      final calls = await FlutterCallkitIncoming.activeCalls();
      return calls.any(
        (call) => _sameCallId(call.id, callId) && !call.isAccepted,
      );
    } catch (error) {
      debugPrint('callkit activeCalls: $error');
      return false;
    }
  }

  @override
  Future<List<String>> ringingCalls() async {
    if (kIsWeb) {
      return const [];
    }
    try {
      final calls = await FlutterCallkitIncoming.activeCalls();
      return [
        for (final call in calls)
          if (!call.isAccepted && call.id.isNotEmpty) call.id,
      ];
    } catch (error) {
      debugPrint('callkit activeCalls: $error');
      return const [];
    }
  }

  static bool _sameCallId(String? a, String? b) =>
      a != null && b != null && a.trim().toLowerCase() == b.trim().toLowerCase();

  /// Audio-only, Vietnamese labels, ring for the server's ring window.
  static CallKitParams paramsFor(NativeIncomingCall call) => CallKitParams(
    id: call.callId,
    nameCaller: call.callerLabel,
    appName: 'DealGo',
    handle: call.subtitle,
    type: 0,
    duration: call.ringSeconds * 1000,
    extra: <String, dynamic>{
      for (final e in call.data.entries)
        if (e.value != null) e.key: '${e.value}',
    },
    missedCallNotification: const NotificationParams(
      showNotification: false,
      isShowCallback: false,
    ),
    callingNotification: const NotificationParams(
      showNotification: true,
      isShowCallback: true,
      subtitle: 'Đang gọi…',
      callbackText: 'Kết thúc',
    ),
    android: const AndroidParams(
      isCustomNotification: true,
      isShowLogo: false,
      // Without this the receiver only posts a heads-up notification and the
      // plugin stops the ringtone on ACTION_SCREEN_OFF, so a locked phone
      // never rings. The activity itself needs USE_FULL_SCREEN_INTENT.
      isFullScreen: true,
      ringtonePath: 'system_ringtone_default',
      backgroundColor: '#0F766E',
      actionColor: '#16A34A',
      textColor: '#ffffff',
      incomingCallNotificationChannelName: 'Cuộc gọi đến',
      missedCallNotificationChannelName: 'Cuộc gọi nhỡ',
      isShowCallID: false,
      textAccept: 'Nghe',
      textDecline: 'Từ chối',
    ),
    ios: const IOSParams(
      handleType: 'generic',
      supportsVideo: false,
      maximumCallGroups: 1,
      maximumCallsPerCallGroup: 1,
      // CallKit activates AVAudioSession and LiveKit configures RTCAudioSession
      // under externalCallSystem; the plugin's own setActive/1200ms timer would
      // fight WebRTC and trigger -4100 audio session failures.
      configureAudioSession: false,
      audioSessionMode: 'voiceChat',
      audioSessionActive: true,
      supportsDTMF: false,
      supportsHolding: false,
      supportsGrouping: false,
      supportsUngrouping: false,
      ringtonePath: 'system_ringtone_default',
    ),
  );

  static NativeCallAction? _toAction(CallEvent? event) => switch (event) {
    CallEventActionCallAccept(:final callKitParams) => NativeCallAction(
      NativeCallActionType.accepted,
      callKitParams.id,
      _extra(callKitParams.extra),
    ),
    CallEventActionCallDecline(:final callKitParams) => NativeCallAction(
      NativeCallActionType.declined,
      callKitParams.id,
      _extra(callKitParams.extra),
    ),
    CallEventActionCallEnded(:final callKitParams) => NativeCallAction(
      NativeCallActionType.ended,
      callKitParams.id,
      _extra(callKitParams.extra),
    ),
    CallEventActionCallIncoming(:final callKitParams) => NativeCallAction(
      NativeCallActionType.shown,
      callKitParams.id,
      _extra(callKitParams.extra),
    ),
    CallEventActionCallTimeout(:final id) => NativeCallAction(
      NativeCallActionType.timedOut,
      id,
    ),
    _ => null,
  };

  static Map<String, Object?> _extra(Map<String, dynamic>? extra) =>
      extra == null ? const {} : Map<String, Object?>.of(extra);

  static Future<void> _guard(Future<void> Function() run) async {
    try {
      await run();
    } catch (error) {
      debugPrint('callkit: $error');
    }
  }
}

/// FCM background isolate (Android, app in background or killed): an incoming
/// call push rings the system call screen; a missed/ended push takes it down.
Future<void> handleCallPushInBackground(
  Map<String, Object?> data, {
  String? title,
  String? body,
  NativeCallUi? ui,
  TokenStore? tokenStore,
}) async {
  if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) {
    // iOS rings through PushKit → CallKit in AppDelegate instead.
    return;
  }
  if (tokenStore != null) {
    try {
      final tokens = await tokenStore.read();
      if (tokens == null || tokens.accessToken.trim().isEmpty) {
        return;
      }
    } catch (_) {
      return;
    }
  }
  final native = ui ?? CallkitNativeCallUi();
  // Incoming calls are data-only on Android (no FCM tray copy beside the
  // call screen), so the caller label rides in data.
  final incoming = NativeIncomingCall.fromPush(
    data,
    title: title ?? _text(data['title']),
    body: body ?? _text(data['body']),
  );
  if (incoming != null) {
    await native.showIncoming(incoming);
    return;
  }
  final callId = data['callId'];
  const dismissEvents = {'Call.missed', 'Call.cancelled', 'Call.ended'};
  if (dismissEvents.contains(data['eventType']) && callId is String) {
    await native.dismiss(callId);
  }
}

String? _text(Object? raw) =>
    raw is String && raw.trim().isNotEmpty ? raw : null;
