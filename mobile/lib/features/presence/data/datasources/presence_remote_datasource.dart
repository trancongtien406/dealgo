abstract interface class PresenceRemoteDataSource {
  Future<void> setPresence({
    required String accessToken,
    required bool online,
    double? lat,
    double? lng,
  });
}

/// Backward-compatible alias used by mocks, tests, and DI overrides.
typedef PresenceClient = PresenceRemoteDataSource;
