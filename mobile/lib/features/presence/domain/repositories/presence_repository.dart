import '../entities/driver_service_prefs.dart';

abstract interface class PresenceRepository {
  Future<void> setPresence({
    required String accessToken,
    required bool online,
    double? lat,
    double? lng,
    bool? rideEnabled,
    bool? foodEnabled,
  });

  Future<DriverServicePrefs> getServicePrefs({required String accessToken});
}
