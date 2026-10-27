import '../entities/voice_models.dart';
import '../repositories/voice_repository.dart';

/// Callee side of a ringing call: accept (returns the join token) or decline.
class AnswerVoiceCall {
  const AnswerVoiceCall(this._repository);

  final VoiceRepository _repository;

  Future<VoiceCallJoin> accept({
    required String accessToken,
    required String callId,
  }) => _repository.accept(accessToken: accessToken, callId: callId);

  Future<VoiceCall> decline({
    required String accessToken,
    required String callId,
  }) => _repository.decline(accessToken: accessToken, callId: callId);
}
