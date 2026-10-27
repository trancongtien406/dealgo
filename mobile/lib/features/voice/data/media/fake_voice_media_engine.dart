import 'dart:async';

import '../../domain/ports/voice_media_engine.dart';

/// No audio: records what the call controller asked for. Used by mock builds
/// and tests.
class FakeVoiceMediaEngine implements VoiceMediaEngine {
  FakeVoiceMediaEngine({this.micGranted = true});

  bool micGranted;
  Object? joinError;
  final List<String> log = [];
  bool joined = false;
  bool micOn = false;
  bool speakerOn = false;
  final _events = StreamController<VoiceMediaEvent>.broadcast();

  @override
  Stream<VoiceMediaEvent> get events => _events.stream;

  void emit(VoiceMediaEvent event) => _events.add(event);

  @override
  Future<bool> ensureMicrophonePermission() async => micGranted;

  @override
  Future<void> join({required String url, required String token}) async {
    log.add('join:$url');
    final err = joinError;
    if (err != null) {
      throw err;
    }
    joined = true;
    micOn = true;
  }

  @override
  Future<void> setMicrophoneEnabled(bool enabled) async {
    log.add('mic:$enabled');
    micOn = enabled;
  }

  @override
  Future<void> setSpeakerOn(bool on) async {
    log.add('speaker:$on');
    speakerOn = on;
  }

  @override
  Future<void> leave() async {
    if (joined) {
      log.add('leave');
    }
    joined = false;
    micOn = false;
  }
}
