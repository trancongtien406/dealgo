abstract interface class PresenceRepository {
  Future<void> setPresence({
    required String accessToken,
    required bool online,
    double? lat,
    double? lng,
  });
}
