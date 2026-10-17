import '../params/set_presence_params.dart';
import '../repositories/presence_repository.dart';

class SetPresence {
  const SetPresence(this._repository);

  final PresenceRepository _repository;

  Future<void> call(SetPresenceParams params) {
    return _repository.setPresence(
      accessToken: params.accessToken,
      online: params.online,
      lat: params.lat,
      lng: params.lng,
    );
  }
}
