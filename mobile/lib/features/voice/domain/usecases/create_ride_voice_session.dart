import '../entities/voice_models.dart';
import '../params/create_voice_session_params.dart';
import '../repositories/voice_repository.dart';

class CreateRideVoiceSession {
  const CreateRideVoiceSession(this._repository);

  final VoiceRepository _repository;

  Future<VoiceSession> call(CreateRideVoiceSessionParams params) {
    return _repository.createRideVoiceSession(
      accessToken: params.accessToken,
      rideId: params.rideId,
    );
  }
}
