import '../entities/voice_models.dart';
import '../params/create_voice_session_params.dart';
import '../repositories/voice_repository.dart';

class CreateFoodOrderVoiceSession {
  const CreateFoodOrderVoiceSession(this._repository);

  final VoiceRepository _repository;

  Future<VoiceSession> call(CreateFoodOrderVoiceSessionParams params) {
    return _repository.createFoodOrderVoiceSession(
      accessToken: params.accessToken,
      orderId: params.orderId,
    );
  }
}
