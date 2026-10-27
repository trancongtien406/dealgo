import 'dart:async';
import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_ringtone_player/flutter_ringtone_player.dart';

import '../../domain/ports/call_ringer.dart';

/// Device ringtone for an incoming in-app call.
///
/// Android loops the user's default ringtone natively. iOS system sounds play
/// once, so the sound is re-triggered every [iosRepeat]. Vibration pulses every
/// [vibrateEvery] on both. Every platform error is swallowed: a missing
/// ringtone must never break answering the call.
class SystemCallRinger implements CallRinger {
  SystemCallRinger({
    FlutterRingtonePlayer? player,
    bool? loopsNatively,
    this.iosRepeat = const Duration(seconds: 3),
    this.vibrateEvery = const Duration(seconds: 2),
  }) : _player = player ?? FlutterRingtonePlayer(),
       _loopsNatively = loopsNatively ?? (!kIsWeb && Platform.isAndroid);

  final FlutterRingtonePlayer _player;
  final bool _loopsNatively;
  final Duration iosRepeat;
  final Duration vibrateEvery;

  Timer? _soundTimer;
  Timer? _vibrateTimer;
  bool _ringing = false;

  bool get ringing => _ringing;

  @override
  Future<void> start() async {
    if (_ringing) {
      return;
    }
    _ringing = true;
    _vibrate();
    _vibrateTimer = Timer.periodic(vibrateEvery, (_) => _vibrate());
    if (_loopsNatively) {
      await _guard(() => _player.playRingtone(looping: true, asAlarm: false));
      return;
    }
    await _guard(_playOnce);
    _soundTimer = Timer.periodic(
      iosRepeat,
      (_) => unawaited(_guard(_playOnce)),
    );
  }

  @override
  Future<void> stop() async {
    final wasRinging = _ringing;
    _ringing = false;
    _soundTimer?.cancel();
    _soundTimer = null;
    _vibrateTimer?.cancel();
    _vibrateTimer = null;
    if (wasRinging) {
      await _guard(_player.stop);
    }
  }

  Future<void> _playOnce() =>
      _player.play(ios: IosSounds.electronic, looping: false, asAlarm: false);

  void _vibrate() {
    unawaited(_guard(HapticFeedback.vibrate));
  }

  static Future<void> _guard(Future<void> Function() action) async {
    try {
      await action();
    } catch (error) {
      debugPrint('call ringer: $error');
    }
  }
}
