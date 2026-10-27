import '../entities/voice_models.dart';
import '../repositories/voice_repository.dart';

/// Hang up. While the call still rings the server records it as missed.
class EndVoiceCall {
  const EndVoiceCall(this._repository);

  final VoiceRepository _repository;

  Future<VoiceCall> call({
    required String accessToken,
    required String callId,
  }) => _repository.end(accessToken: accessToken, callId: callId);
}
