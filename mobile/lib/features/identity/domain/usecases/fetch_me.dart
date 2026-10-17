import '../entities/user_profile.dart';
import '../repositories/identity_repository.dart';

class FetchMe {
  const FetchMe(this._repository);

  final IdentityRepository _repository;

  Future<UserProfile> call(String accessToken) {
    return _repository.fetchMe(accessToken);
  }
}
