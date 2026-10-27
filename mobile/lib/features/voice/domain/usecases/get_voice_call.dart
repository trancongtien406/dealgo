import '../entities/voice_models.dart';
import '../repositories/voice_repository.dart';

/// Authoritative call state (after a push tap or a socket reconnect).
class GetVoiceCall {
  const GetVoiceCall(this._repository);

  final VoiceRepository _repository;

  Future<VoiceCall> call({
    required String accessToken,
    required String callId,
  }) => _repository.get(accessToken: accessToken, callId: callId);
}
