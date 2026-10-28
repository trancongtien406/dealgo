import 'package:audioplayers/audioplayers.dart';

/// Audio settings for short in-app alerts (new-job sound, incoming-call ring).
///
/// iOS: `ambient` mixes with other audio and follows the silent switch. The
/// iOS audio session is app-wide (audioplayers applies it globally and
/// deactivates it when the clip ends), so alerts must never play during a
/// live voice call; callers check that first.
/// Android: [ring] uses the ringtone stream (silent when the ringer is off),
/// [notification] the notification stream; both only duck other audio.
abstract final class AlertAudio {
  static final AudioContext notification = AudioContext(
    android: const AudioContextAndroid(
      contentType: AndroidContentType.sonification,
      usageType: AndroidUsageType.notification,
      audioFocus: AndroidAudioFocus.gainTransientMayDuck,
    ),
    iOS: AudioContextIOS(category: AVAudioSessionCategory.ambient),
  );

  static final AudioContext ring = AudioContext(
    android: const AudioContextAndroid(
      contentType: AndroidContentType.sonification,
      usageType: AndroidUsageType.notificationRingtone,
      audioFocus: AndroidAudioFocus.gainTransientMayDuck,
    ),
    iOS: AudioContextIOS(category: AVAudioSessionCategory.ambient),
  );

  /// Built-in short "ding" (used when the spoken new-job sound is off).
  static const notifyAsset = 'assets/sounds/dealgo_notify.mp3';

  /// Two-tone ring (2 s on, 1 s off) looped while a call rings in-app.
  static const ringAsset = 'assets/sounds/dealgo_call_ring.mp3';

  /// `assets/sounds/x.mp3` → [AssetSource] (its cache already adds `assets/`).
  static AssetSource source(String asset) => AssetSource(
    asset.startsWith('assets/') ? asset.substring('assets/'.length) : asset,
  );
}
