/// Audio transport for a call (LiveKit in the app, a fake in tests).
abstract interface class VoiceMediaEngine {
  /// Asks for the microphone permission when needed; false when refused.
  Future<bool> ensureMicrophonePermission();

  /// Joins the room with the microphone on and remote audio playing.
  ///
  /// [systemCallOwnsAudio] is true when CallKit/Telecom has already accepted
  /// the call and therefore owns the platform audio-session lifecycle.
  Future<void> join({
    required String url,
    required String token,
    bool systemCallOwnsAudio = false,
  });

  Future<void> setMicrophoneEnabled(bool enabled);

  Future<void> setSpeakerOn(bool on);

  /// Leaves the room; safe to call when not joined.
  Future<void> leave();

  Stream<VoiceMediaEvent> get events;
}

enum VoiceMediaEvent {
  /// The other party's audio is connected.
  remoteJoined,

  /// The other party left the room (hung up, app killed, lost network for good).
  remoteLeft,

  /// Our own connection is retrying.
  reconnecting,
  reconnected,

  /// Our connection to the room was lost and could not be restored.
  disconnected,
}

typedef VoiceMediaEngineFactory = VoiceMediaEngine Function();
