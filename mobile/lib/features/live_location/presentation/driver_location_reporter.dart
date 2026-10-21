import 'dart:async';

import '../../../core/location/location_service.dart';
import '../domain/driver_location.dart';

/// DEC-PROD-031: while the driver is online the app reports a foreground GPS
/// fix every [interval]. Failures are silent: tracking is best-effort and must
/// never block taking jobs.
class DriverLocationReporter {
  DriverLocationReporter({
    required this.repository,
    required this.location,
    required this.accessToken,
    this.interval = const Duration(seconds: 15),
  });

  final DriverLocationRepository repository;
  final LocationService location;
  final String? Function() accessToken;
  final Duration interval;

  Timer? _timer;
  var _sending = false;

  bool get running => _timer != null;

  void start() {
    if (_timer != null) {
      return;
    }
    _timer = Timer.periodic(interval, (_) => unawaited(tick()));
    unawaited(tick());
  }

  void stop() {
    _timer?.cancel();
    _timer = null;
  }

  /// Sends one fix; public so tests can drive it without timers.
  Future<void> tick() async {
    final token = accessToken()?.trim() ?? '';
    if (_sending || token.isEmpty) {
      return;
    }
    _sending = true;
    try {
      final position = await location.currentPosition();
      if (position == null || _timer == null) {
        return;
      }
      await repository.report(
        accessToken: token,
        lat: position.latitude,
        lng: position.longitude,
      );
    } catch (_) {
      // Best-effort: next tick retries.
    } finally {
      _sending = false;
    }
  }
}
