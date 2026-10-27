import '../entities/voice_models.dart';
import '../repositories/voice_repository.dart';

/// Whether the call button should show (admin toggle + provider configured).
class GetVoiceCallConfig {
  const GetVoiceCallConfig(this._repository);

  final VoiceRepository _repository;

  Future<VoiceCallConfig> call({required String accessToken}) =>
      _repository.config(accessToken: accessToken);
}
