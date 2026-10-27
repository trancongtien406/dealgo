import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:livekit_client/livekit_client.dart';
import 'package:permission_handler/permission_handler.dart';

import '../../domain/ports/voice_media_engine.dart';
import 'livekit_url_policy.dart';

/// Audio-only LiveKit room. The token from the API grants publish of the
/// microphone only, so a client cannot send video even if it tried.
class LiveKitVoiceMediaEngine implements VoiceMediaEngine {
  final _events = StreamController<VoiceMediaEvent>.broadcast();
  Room? _room;
  EventsListener<RoomEvent>? _listener;
  bool _leaving = false;

  @override
  Stream<VoiceMediaEvent> get events => _events.stream;

  @override
  Future<bool> ensureMicrophonePermission() async {
    final status = await Permission.microphone.request();
    final granted = status.isGranted || status.isLimited;
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
  Future<void> join({required String url, required String token}) async {
    assertLiveKitUrlAllowed(url, isRelease: kReleaseMode);
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
