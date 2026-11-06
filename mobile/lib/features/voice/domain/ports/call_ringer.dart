/// Rings the phone for an incoming call (looping ringtone + vibration) until
/// [stop]. The app uses `AssetCallRinger`; tests use a recording fake.
abstract interface class CallRinger {
  /// Starts ringing; a second call while ringing does nothing.
  Future<void> start();

  /// Stops sound and vibration; safe to call when not ringing.
  Future<void> stop();

  /// Releases the audio player (the call screen is gone for good).
  Future<void> dispose();
}

typedef CallRingerFactory = CallRinger Function();
