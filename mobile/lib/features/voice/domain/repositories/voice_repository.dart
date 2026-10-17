import '../entities/voice_models.dart';

abstract interface class VoiceRepository {
  Future<VoiceSession> createRideVoiceSession({
    required String accessToken,
    required String rideId,
  });

  Future<VoiceSession> createFoodOrderVoiceSession({
    required String accessToken,
    required String orderId,
  });
}
