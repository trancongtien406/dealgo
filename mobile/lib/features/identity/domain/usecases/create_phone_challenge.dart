import '../entities/phone_challenge.dart';
import '../params/create_phone_challenge_params.dart';
import '../repositories/identity_repository.dart';

class CreatePhoneChallenge {
  const CreatePhoneChallenge(this._repository);

  final IdentityRepository _repository;

  Future<PhoneChallenge> call(CreatePhoneChallengeParams params) {
    return _repository.createPhoneChallenge(params.phone);
  }
}
