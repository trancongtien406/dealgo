import 'dart:async';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../../../../core/media/alert_audio.dart';
import '../../domain/ports/call_ringer.dart';

/// Ring for an incoming call shown by the in-app call screen.
///
/// Loops the bundled [AlertAudio.ringAsset] on Android and iOS and pulses
/// vibration every [vibrateEvery]. Calls rung by CallKit / ConnectionService
/// use the system ringtone and never start this ringer. Every platform error is
/// swallowed: a missing sound must never break answering the call.
class AssetCallRinger implements CallRinger {
  AssetCallRinger({
    AudioPlayer? player,
    this.vibrateEvery = const Duration(seconds: 2),
  }) : _given = player;

  final AudioPlayer? _given;
  late final AudioPlayer _player =
      _given ?? AudioPlayer(playerId: 'dealgo-call-ring');
  final Duration vibrateEvery;

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
    await _guard(() async {
      await _player.setReleaseMode(ReleaseMode.loop);
      await _player.play(
        AlertAudio.source(AlertAudio.ringAsset),
        ctx: AlertAudio.ring,
      );
    });
    if (!_ringing) {
      // stop() ran while the sound was still loading.
      await _guard(_player.stop);
    }
  }

  @override
  Future<void> stop() async {
    final wasRinging = _ringing;
    _ringing = false;
    _vibrateTimer?.cancel();
    _vibrateTimer = null;
    if (wasRinging) {
      await _guard(_player.stop);
    }
  }

  @override
  Future<void> dispose() async {
    await stop();
    await _guard(_player.dispose);
  }

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
