import '../entities/verified_session.dart';
import '../params/verify_phone_params.dart';
import '../repositories/identity_repository.dart';

class VerifyPhoneChallenge {
  const VerifyPhoneChallenge(this._repository);

  final IdentityRepository _repository;

  Future<VerifiedSession> call(VerifyPhoneParams params) {
    return _repository.verifyPhoneChallenge(
      challengeId: params.challengeId,
      code: params.code,
    );
  }
}
