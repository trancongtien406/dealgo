/// What the user did on the system call screen (Android ConnectionService UI,
/// iOS CallKit).
enum NativeCallActionType {
  accepted,
  declined,
  timedOut,
  ended,

  /// The system call screen started ringing this call (PushKit → CallKit, or
  /// the Android background push). The app's own ringtone must then stay off.
  shown,
}

class NativeCallAction {
  const NativeCallAction(this.type, this.callId, [this.data = const {}]);

  final NativeCallActionType type;
  final String callId;

  /// The push data the call was shown with (eventType, callId, path, role…).
  final Map<String, Object?> data;
}

/// An incoming call to show on the system call screen.
class NativeIncomingCall {
  const NativeIncomingCall({
    required this.callId,
    required this.callerLabel,
    required this.subtitle,
    required this.ringSeconds,
    required this.data,
  });

  final String callId;
  final String callerLabel;
  final String subtitle;
  final int ringSeconds;
  final Map<String, Object?> data;

  static const _uuid =
      r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$';

  /// `Call.incoming` push → native call; null for any other push. CallKit only
  /// accepts UUID call ids, which is what the server issues.
  static NativeIncomingCall? fromPush(
    Map<String, Object?> data, {
    String? title,
    String? body,
    int ringSeconds = 40,
  }) {
    final callId = data['callId'];
    if (data['eventType'] != 'Call.incoming' ||
        callId is! String ||
        !RegExp(_uuid).hasMatch(callId)) {
      return null;
    }
    final role = data['role'];
    final caller = (title != null && title.trim().isNotEmpty)
        ? title.trim()
        : role == 'DRIVER'
        ? 'Khách đang gọi cho bạn'
        : 'Tài xế đang gọi cho bạn';
    final seconds = int.tryParse('${data['ringSeconds'] ?? ''}') ?? ringSeconds;
    return NativeIncomingCall(
      callId: callId,
      callerLabel: caller,
      subtitle: body?.trim().isNotEmpty == true ? body!.trim() : 'DealGo',
      ringSeconds: seconds,
      data: Map<String, Object?>.of(data),
    );
  }
}

/// System call UI port: rings like a phone call while the app is in the
/// background or killed, and reports the user's choice back to the app.
abstract interface class NativeCallUi {
  Stream<NativeCallAction> get actions;

  Future<void> showIncoming(NativeIncomingCall call);

  /// Stops ringing / removes the system call (answered in-app, missed, ended).
  Future<void> dismiss(String callId);

  /// Ends every system call except [keepCallId] (null: none).
  ///
  /// A ringing notification outlives the app process, so after a kill or a
  /// long suspend the OS can still show a call the server already ended.
  Future<void> dismissOthers(String? keepCallId);

  /// Marks a call answered from the system UI as connected (iOS call timer).
  Future<void> setConnected(String callId);

  /// Calls answered on the system UI before the app's Dart side was listening.
  Future<List<NativeCallAction>> acceptedOnLaunch();

  /// iOS PushKit token (registered as platform `ios-voip`); null elsewhere.
  Future<String?> voipPushToken();

  /// Fires when iOS hands the app a new PushKit token (it often arrives after
  /// sign-in already registered the FCM token), so it is uploaded again.
  Stream<void> get voipTokenChanges;

  /// Android 14+: asks once per install for the full-screen call permission,
  /// so an incoming call opens the call screen over the lock screen instead
  /// of only a heads-up notification. No-op elsewhere / when granted.
  Future<void> ensureFullScreenCalls();

  /// Whether the system call screen is already ringing [callId] (so the
  /// in-app ringtone would ring a second time).
  Future<bool> isRinging(String callId);

  /// Call IDs currently ringing (unanswered) on the system call screen.
  Future<List<String>> ringingCalls();
}

/// Web, tests and mock builds.
class NoopNativeCallUi implements NativeCallUi {
  const NoopNativeCallUi();

  @override
  Stream<NativeCallAction> get actions => const Stream.empty();

  @override
  Future<void> showIncoming(NativeIncomingCall call) async {}

  @override
  Future<void> dismiss(String callId) async {}

  @override
  Future<void> dismissOthers(String? keepCallId) async {}

  @override
  Future<void> setConnected(String callId) async {}

  @override
  Future<List<NativeCallAction>> acceptedOnLaunch() async => const [];

  @override
  Future<String?> voipPushToken() async => null;

  @override
  Stream<void> get voipTokenChanges => const Stream.empty();

  @override
  Future<void> ensureFullScreenCalls() async {}

  @override
  Future<bool> isRinging(String callId) async => false;

  @override
  Future<List<String>> ringingCalls() async => const [];
}
