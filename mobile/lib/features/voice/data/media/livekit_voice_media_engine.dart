// LiveKit marks its CallKit audio-ownership API experimental in 2.13.x even
// though it is the supported integration path for iOS system calls.
// ignore_for_file: experimental_member_use

import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:livekit_client/livekit_client.dart';
import 'package:permission_handler/permission_handler.dart';

import '../../../../core/observability/performance_monitoring.dart';
import '../../domain/ports/voice_media_engine.dart';
import 'livekit_url_policy.dart';

/// Audio-only LiveKit room. The token from the API grants publish of the
/// microphone only, so a client cannot send video even if it tried.
class LiveKitVoiceMediaEngine implements VoiceMediaEngine {
  final _events = StreamController<VoiceMediaEvent>.broadcast();
  Room? _room;
  EventsListener<RoomEvent>? _listener;
  bool _leaving = false;
  bool _microphonePermissionJustGranted = false;

  @override
  Stream<VoiceMediaEvent> get events => _events.stream;

  @override
  Future<bool> ensureMicrophonePermission() async {
    // The OS microphone prompt cannot render over another app or the lock
    // screen: requesting there returns `denied` immediately and the call is
    // dropped even though the user would have allowed it. Answering from
    // CallKit/Telecom brings the app forward within a few hundred ms, so wait
    // for the foreground before asking — but only when still undecided.
    final wasGranted = await Permission.microphone.isGranted;
    if (!wasGranted) {
      await waitForForeground(const Duration(seconds: 3));
    }
    final status = await Permission.microphone.request();
    final granted = status.isGranted || status.isLimited;
    _microphonePermissionJustGranted = granted && !wasGranted;
    if (granted) {
      await _ensureBluetoothConnect();
    }
    return granted;
  }

  /// Android 12+: BLUETOOTH_CONNECT (runtime permission) lets the call audio
  /// route to a paired headset. Optional: refused → the call stays on the
  /// phone's earpiece/speaker.
  Future<void> _ensureBluetoothConnect() async {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) {
      return;
    }
    try {
      if (!await Permission.bluetoothConnect.isGranted) {
        await Permission.bluetoothConnect.request();
      }
    } catch (error) {
      debugPrint('bluetoothConnect permission: $error');
    }
  }

  @override
  Future<void> join({
    required String url,
    required String token,
    bool systemCallOwnsAudio = false,
  }) async {
    assertLiveKitUrlAllowed(url, isRelease: kReleaseMode);
    // Audio session setup is the slowest, most failure-prone step of a call;
    // `audio_session_retried` separates healthy joins from the -4100 retries.
    final trace = PerformanceMonitoring.instance.startTrace('voice_call_join');
    try {
      await _configureAudioOwnership(systemCallOwnsAudio);
      if (_microphonePermissionJustGranted) {
        _microphonePermissionJustGranted = false;
        trace.putAttribute('microphone_permission_just_granted', 'true');
        await waitForAudioSessionRecovery(
          foregroundTimeout: const Duration(seconds: 3),
          settleDelay: const Duration(milliseconds: 350),
        );
      }
      // AVAudioSession activation from the background fails with -4100
      // (Sentry). Give the app a moment to come to the foreground first; CallKit
      // answers from the lock screen still go ahead after the short wait.
      await waitForForeground(const Duration(seconds: 3));
      await runWithAudioSessionRetry(
        () => _joinOnce(url: url, token: token),
        beforeRetry: () async {
          trace.putAttribute('audio_session_retried', 'true');
          await leave();
          await waitForAudioSessionRecovery(
            foregroundTimeout: const Duration(seconds: 10),
            settleDelay: const Duration(milliseconds: 500),
          );
        },
      );
    } catch (_) {
      trace.putAttribute('outcome', 'failed');
      rethrow;
    } finally {
      await trace.stop();
    }
  }

  Future<void> _configureAudioOwnership(bool systemCallOwnsAudio) async {
    // externalCallSystem currently retains LiveKit's automatic Android audio
    // focus/routing, while reserving ownership for the self-managed Telecom
    // connection. On iOS it hands activation to CallKit.
    await AudioManager.instance.setAudioSessionManagementMode(
      systemCallOwnsAudio
          ? AudioSessionManagementMode.externalCallSystem
          : AudioSessionManagementMode.automatic,
    );
    if (!systemCallOwnsAudio) {
      await AudioManager.instance.setEngineAvailability(
        AudioEngineAvailability.defaultAvailability,
      );
    }
  }

  Future<void> _joinOnce({required String url, required String token}) async {
    await leave();
    _leaving = false;
    final room = Room(
      roomOptions: const RoomOptions(
        adaptiveStream: false,
        dynacast: false,
        defaultAudioCaptureOptions: AudioCaptureOptions(
          echoCancellation: true,
          noiseSuppression: true,
          autoGainControl: true,
        ),
      ),
    );
    final listener = room.createListener();
    listener
      ..on<ParticipantConnectedEvent>(
        (_) => _emit(VoiceMediaEvent.remoteJoined),
      )
      ..on<TrackSubscribedEvent>((_) => _emit(VoiceMediaEvent.remoteJoined))
      ..on<ParticipantDisconnectedEvent>(
        (_) => _emit(VoiceMediaEvent.remoteLeft),
      )
      ..on<RoomReconnectingEvent>((_) => _emit(VoiceMediaEvent.reconnecting))
      ..on<RoomReconnectedEvent>((_) => _emit(VoiceMediaEvent.reconnected))
      ..on<RoomDisconnectedEvent>((_) {
        if (!_leaving) {
          _emit(VoiceMediaEvent.disconnected);
        }
      });
    _room = room;
    _listener = listener;
    await room.connect(url, token);
    await room.localParticipant?.setMicrophoneEnabled(true);
    // Phone call by default: earpiece, user can switch to speaker.
    await AudioManager.instance.setSpeakerOutputPreferred(false);
    if (room.remoteParticipants.isNotEmpty) {
      _emit(VoiceMediaEvent.remoteJoined);
    }
  }

  @override
  Future<void> setMicrophoneEnabled(bool enabled) async {
    await _room?.localParticipant?.setMicrophoneEnabled(enabled);
  }

  @override
  Future<void> setSpeakerOn(bool on) =>
      AudioManager.instance.setSpeakerOutputPreferred(on);

  @override
  Future<void> leave() async {
    final room = _room;
    final listener = _listener;
    _room = null;
    _listener = null;
    if (room == null) {
      return;
    }
    _leaving = true;
    try {
      await room.disconnect();
    } finally {
      await listener?.dispose();
      await room.dispose();
    }
  }

  void _emit(VoiceMediaEvent event) {
    if (!_events.isClosed) {
      _events.add(event);
    }
  }
}

/// AVAudioSession refused to activate (`-4100` / interruption), typically
/// because the app was not in the foreground yet.
@visibleForTesting
bool isAudioSessionError(Object error) {
  final text = error.toString();
  return text.contains('-4100') ||
      text.contains('AudioSession') ||
      text.toLowerCase().contains('interruption');
}

/// Runs [attempt]; on an audio-session failure runs [beforeRetry] (tear down,
/// wait for resume) and tries exactly once more. Other errors rethrow at once.
@visibleForTesting
Future<void> runWithAudioSessionRetry(
  Future<void> Function() attempt, {
  required Future<void> Function() beforeRetry,
}) async {
  try {
    await attempt();
  } catch (error) {
    if (!isAudioSessionError(error)) rethrow;
    await beforeRetry();
    await attempt();
  }
}

/// Completes when the app is resumed, or after [timeout] (whichever first).
Future<void> waitForForeground(Duration timeout) async {
  final state = WidgetsBinding.instance.lifecycleState;
  if (state == null || state == AppLifecycleState.resumed) return;
  final resumed = Completer<void>();
  final listener = AppLifecycleListener(
    onResume: () {
      if (!resumed.isCompleted) resumed.complete();
    },
  );
  try {
    await resumed.future.timeout(timeout, onTimeout: () {});
  } finally {
    listener.dispose();
  }
}

/// Waits for both foreground delivery and the AVAudioSession transition to
/// settle. A lifecycle-only retry returns immediately while the app is already
/// resumed, which repeats error -4100 in the same invalid audio state.
@visibleForTesting
Future<void> waitForAudioSessionRecovery({
  required Duration foregroundTimeout,
  required Duration settleDelay,
  Future<void> Function(Duration duration) delay = Future<void>.delayed,
}) async {
  await waitForForeground(foregroundTimeout);
  await delay(settleDelay);
}
