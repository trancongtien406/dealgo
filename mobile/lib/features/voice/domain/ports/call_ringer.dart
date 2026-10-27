/// Rings the phone for an incoming call (looping ringtone + vibration) until
/// [stop]. The app uses the system ringtone; tests use a recording fake.
abstract interface class CallRinger {
  /// Starts ringing; a second call while ringing does nothing.
  Future<void> start();

  /// Stops sound and vibration; safe to call when not ringing.
  Future<void> stop();
}

typedef CallRingerFactory = CallRinger Function();
