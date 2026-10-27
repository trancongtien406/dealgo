import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_ringtone_player/flutter_ringtone_player.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Kinds of "new job" alert, mirroring backend `NEW_JOB_SOUNDS` (r26).
enum NewJobAlertKind {
  ride('dealgo_new_ride', 'dealgo_new_ride_v1'),
  foodJob('dealgo_new_food_job', 'dealgo_new_food_job_v1'),
  merchantOrder('dealgo_merchant_new_order', 'dealgo_merchant_new_order_v1');

  const NewJobAlertKind(this.soundName, this.androidChannelId);

  /// File base name: `assets/sounds/<name>.mp3`, Android `res/raw/<name>.ogg`, iOS `<name>.caf`.
  final String soundName;

  /// Android notification channel that plays the sound (created in MainActivity).
  final String androidChannelId;

  String get asset => 'assets/sounds/$soundName.mp3';
}

/// Android channel for new-job pushes when the spoken sound is off.
const newJobDefaultSoundChannelId = 'dealgo_new_job_default_v1';

/// Which alert a push stands for, from its data payload; null = not a new job.
NewJobAlertKind? newJobAlertKindForPush(Map<String, Object?> data) {
  String? field(String key) => data[key]?.toString();
  final eventType = field('eventType') ?? '';
  switch (eventType) {
    case 'Ride.request.nearby':
      return NewJobAlertKind.ride;
    case 'FoodOrder.request.nearby':
      return NewJobAlertKind.foodJob;
  }
  if (field('aggregateType') == 'FoodOrder' &&
      field('role') == 'MERCHANT' &&
      field('status') == 'PLACED' &&
      !eventType.startsWith('FoodOrder.change.')) {
    return NewJobAlertKind.merchantOrder;
  }
  return null;
}

/// Sound + vibration backend (fake in tests).
abstract interface class NewJobAlertPlayer {
  Future<void> playAsset(String asset);
  Future<void> playDefault();
  Future<void> vibrate();
}

class RingtoneNewJobAlertPlayer implements NewJobAlertPlayer {
  RingtoneNewJobAlertPlayer({FlutterRingtonePlayer? player})
    : _player = player ?? FlutterRingtonePlayer();

  final FlutterRingtonePlayer _player;

  @override
  Future<void> playAsset(String asset) =>
      _player.play(fromAsset: asset, looping: false, asAlarm: false);

  @override
  Future<void> playDefault() => _player.playNotification();

  @override
  Future<void> vibrate() => HapticFeedback.vibrate();
}

/// In-app "DealGo, có cuốc mới" alert while the app is in the foreground (r26).
///
/// Background / killed: the OS plays the push sound (iOS `aps.sound`, Android channel).
/// Foreground: Android shows no system notification, so the FCM onMessage path and the
/// merchant store socket call [alert]. iOS presents the foreground push with its sound
/// already, so socket-only triggers are skipped there ([socketTriggersPlay]).
///
/// Bursts are merged: every trigger within [debounce] of the last sound is dropped
/// (3 jobs in 2 s → one sound; push + socket for the same order → one sound).
/// [debounce] is longer than the longest clip (~5 s) so sounds never overlap.
class NewJobAlert {
  NewJobAlert({
    NewJobAlertPlayer? player,
    DateTime Function()? clock,
    this.debounce = const Duration(seconds: 6),
    bool? socketTriggersPlay,
  }) : _player = player ?? RingtoneNewJobAlertPlayer(),
       _clock = clock ?? DateTime.now,
       socketTriggersPlay =
           socketTriggersPlay ??
           (!kIsWeb && defaultTargetPlatform == TargetPlatform.android);

  static const prefKey = 'dealgo.newJobSound';

  /// App-wide instance (foreground push handler, merchant queue, prefs page).
  static final NewJobAlert instance = NewJobAlert();

  final NewJobAlertPlayer _player;
  final DateTime Function() _clock;
  final Duration debounce;
  final bool socketTriggersPlay;

  DateTime? _lastPlayedAt;
  bool _customSound = true;

  /// User's "Âm báo có đơn mới" toggle (cached; server prefs are the source of truth).
  bool get customSound => _customSound;

  /// Load the cached toggle at start-up.
  Future<void> restore() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _customSound = prefs.getBool(prefKey) ?? true;
    } catch (_) {
      _customSound = true;
    }
  }

  /// Called when the notification prefs load or save.
  Future<void> setCustomSound(bool enabled) async {
    _customSound = enabled;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(prefKey, enabled);
    } catch (_) {
      // Cache only; the server copy decides the push sound.
    }
  }

  /// Plays the alert unless one played within [debounce]. Returns whether it played.
  /// [customSound] overrides the cached toggle (a push carries the server's decision).
  Future<bool> alert(NewJobAlertKind kind, {bool? customSound}) async {
    final now = _clock();
    final last = _lastPlayedAt;
    if (last != null && now.difference(last) < debounce) {
      return false;
    }
    _lastPlayedAt = now;
    final spoken = customSound ?? _customSound;
    await _guard(_player.vibrate);
    await _guard(
      spoken ? () => _player.playAsset(kind.asset) : _player.playDefault,
    );
    return true;
  }

  /// Foreground FCM message (Android). Uses data.alertSound set by the backend:
  /// present = spoken file, absent = default sound (admin or user turned it off).
  Future<bool> handlePush(Map<String, Object?> data) async {
    final kind = newJobAlertKindForPush(data);
    if (kind == null) {
      return false;
    }
    final sound = data['alertSound']?.toString() ?? '';
    return alert(kind, customSound: sound.isNotEmpty);
  }

  /// Socket hint (e.g. merchant store room) about a new job.
  Future<bool> handleSocket(NewJobAlertKind kind) async {
    if (!socketTriggersPlay) {
      return false;
    }
    return alert(kind);
  }

  Future<void> _guard(Future<void> Function() action) async {
    try {
      await action();
    } catch (_) {
      // A missing sound must never break the job list.
    }
  }
}
