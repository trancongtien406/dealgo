import '../entities/voice_models.dart';

abstract interface class VoiceRepository {
  Future<VoiceCallConfig> config({required String accessToken});

  /// Rings the other party of the trip and returns the caller's join token.
  Future<VoiceCallJoin> start({
    required String accessToken,
    required VoiceThreadKind kind,
    required String resourceId,
  });

  Future<VoiceCall> get({required String accessToken, required String callId});

  /// Callee answers; returns the callee's join token.
  Future<VoiceCallJoin> accept({
    required String accessToken,
    required String callId,
  });

  Future<VoiceCall> decline({
    required String accessToken,
    required String callId,
  });

  /// Hang up (cancelling while it rings counts as a missed call).
  Future<VoiceCall> end({required String accessToken, required String callId});
}
