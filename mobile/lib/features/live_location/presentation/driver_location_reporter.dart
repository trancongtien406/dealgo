import 'dart:async';

import 'package:geolocator/geolocator.dart';

import '../../../core/location/location_service.dart';
import '../domain/driver_location.dart';

/// DEC-PROD-031 (rev 2026-10-24): adaptive foreground GPS reporting while the
/// driver is online.
///
/// - Cadence comes from the server reply ([DriverLocationPolicy]): ON_TRIP is
///   frequent, IDLE sparse. Until the first reply [initialPolicy] is used.
/// - A fix is sent only when the driver moved at least `minDistanceM` since the
///   last sent fix, or as a keep-alive after `maxSilence`, so a parked driver
///   does not spam the API but also does not go stale.
/// - Each fix carries heading / speed / accuracy / device time so the server
///   can validate it and the customer map can rotate the marker.
///
/// Failures are silent: tracking is best-effort and never blocks taking jobs.
class DriverLocationReporter {
  DriverLocationReporter({
    required this.repository,
    required this.location,
    required this.accessToken,
    DriverLocationPolicy? initialPolicy,
    Duration? interval,
    DateTime Function()? clock,
  }) : _policy = interval == null
           ? (initialPolicy ?? DriverLocationPolicy.idle)
           : DriverLocationPolicy(
               mode: (initialPolicy ?? DriverLocationPolicy.idle).mode,
               interval: interval,
               minDistanceM:
                   (initialPolicy ?? DriverLocationPolicy.idle).minDistanceM,
               maxSilence:
                   (initialPolicy ?? DriverLocationPolicy.idle).maxSilence,
             ),
       _clock = clock ?? DateTime.now;

  final DriverLocationRepository repository;
  final LocationService location;
  final String? Function() accessToken;
  final DateTime Function() _clock;

  DriverLocationPolicy _policy;
  Timer? _timer;
  var _running = false;
  var _sending = false;
  DriverLocationFix? _lastSent;
  DateTime? _lastSentAt;

  bool get running => _running;

  /// Cadence currently in force (server reply or initial).
  DriverLocationPolicy get policy => _policy;

  void start() {
    if (_running) {
      return;
    }
    _running = true;
    _lastSent = null;
    _lastSentAt = null;
    _schedule();
    unawaited(tick());
  }

  void stop() {
    _running = false;
    _timer?.cancel();
    _timer = null;
  }

  void _schedule() {
    _timer?.cancel();
    if (!_running) {
      return;
    }
    _timer = Timer.periodic(_policy.interval, (_) => unawaited(tick()));
  }

  /// Reads one fix and sends it if it passes the distance / keep-alive gate.
  /// Public so tests can drive it without timers.
  Future<void> tick() async {
    final token = accessToken()?.trim() ?? '';
    if (_sending || token.isEmpty || !_running) {
      return;
    }
    _sending = true;
    try {
      final position = await location.currentPosition();
      if (position == null || !_running) {
        return;
      }
      final fix = fixFromPosition(position);
      if (!shouldSend(fix)) {
        return;
      }
      final result = await repository.report(accessToken: token, fix: fix);
      // Count rejected fixes as sent too: retrying the same fix won't help.
      _lastSent = fix;
      _lastSentAt = _clock();
      final next = result.policy;
      if (next != null && _running) {
        final cadenceChanged = next.interval != _policy.interval;
        _policy = next;
        if (cadenceChanged) {
          _schedule();
        }
      }
    } catch (_) {
      // Best-effort: next tick retries.
    } finally {
      _sending = false;
    }
  }

  /// Distance filter + keep-alive.
  bool shouldSend(DriverLocationFix fix) {
    final last = _lastSent;
    final at = _lastSentAt;
    if (last == null || at == null) {
      return true;
    }
    if (_clock().difference(at) >= _policy.maxSilence) {
      return true;
    }
    final moved = Geolocator.distanceBetween(
      last.lat,
      last.lng,
      fix.lat,
      fix.lng,
    );
    return moved >= _policy.minDistanceM;
  }

  /// Geolocator reports -1 / 0 for unknown heading, speed and accuracy on some
  /// platforms; those become null so the server does not trust them.
  static DriverLocationFix fixFromPosition(Position position) {
    double? valid(double v, {bool allowZero = true}) =>
        v.isFinite && (allowZero ? v >= 0 : v > 0) ? v : null;
    final speed = valid(position.speed);
    return DriverLocationFix(
      lat: position.latitude,
      lng: position.longitude,
      // Course is meaningless at a standstill.
      heading: speed != null && speed > 0 ? valid(position.heading) : null,
      speedMps: speed,
      accuracyM: valid(position.accuracy, allowZero: false),
      recordedAt: position.timestamp,
    );
  }
}
