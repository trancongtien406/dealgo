import '../../domain/entities/voice_models.dart';

abstract interface class VoiceRemoteDataSource {
  Future<VoiceSession> createRideVoiceSession({
    required String accessToken,
    required String rideId,
  });

  Future<VoiceSession> createFoodOrderVoiceSession({
    required String accessToken,
    required String orderId,
  });
}

/// Backward-compatible alias used by mocks, tests, and DI overrides.
typedef VoiceClient = VoiceRemoteDataSource;
