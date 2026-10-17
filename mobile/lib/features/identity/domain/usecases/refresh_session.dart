import '../entities/verified_session.dart';
import '../repositories/identity_repository.dart';

class RefreshSession {
  const RefreshSession(this._repository);

  final IdentityRepository _repository;

  Future<VerifiedSession> call(String refreshToken) {
    return _repository.refreshSession(refreshToken);
  }
}
