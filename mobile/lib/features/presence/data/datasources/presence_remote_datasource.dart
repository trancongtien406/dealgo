import '../../domain/entities/driver_service_prefs.dart';

abstract interface class PresenceRemoteDataSource {
  Future<void> setPresence({
    required String accessToken,
    required bool online,
    double? lat,
    double? lng,
    bool? rideEnabled,
    bool? foodEnabled,
  });

  /// The driver's service toggles; defaults when no presence was ever stored.
  Future<DriverServicePrefs> getServicePrefs({required String accessToken});
}

/// Backward-compatible alias used by mocks, tests, and DI overrides.
typedef PresenceClient = PresenceRemoteDataSource;
