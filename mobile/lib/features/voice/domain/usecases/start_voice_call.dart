import '../entities/voice_models.dart';
import '../repositories/voice_repository.dart';

/// Rings the other party of a ride or food order (customer ↔ assigned driver).
class StartVoiceCall {
  const StartVoiceCall(this._repository);

  final VoiceRepository _repository;

  Future<VoiceCallJoin> call({
    required String accessToken,
    required VoiceThreadKind kind,
    required String resourceId,
  }) => _repository.start(
    accessToken: accessToken,
    kind: kind,
    resourceId: resourceId,
  );
}
