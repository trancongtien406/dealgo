import '../../domain/entities/phone_challenge.dart';
import '../../domain/entities/user_profile.dart';
import '../../domain/entities/verified_session.dart';
import '../../domain/repositories/identity_repository.dart';
import '../datasources/identity_remote_datasource.dart';

class IdentityRepositoryImpl implements IdentityRepository {
  IdentityRepositoryImpl(this._remote);

  final IdentityRemoteDataSource _remote;

  @override
  Future<PhoneChallenge> createPhoneChallenge(String phone) async {
    final model = await _remote.createPhoneChallenge(phone);
    return model.toEntity();
  }

  @override
  Future<VerifiedSession> verifyPhoneChallenge({
    required String challengeId,
    required String code,
  }) async {
    final model = await _remote.verifyPhoneChallenge(
      challengeId: challengeId,
      code: code,
    );
    return model.toEntity();
  }

  @override
  Future<VerifiedSession> refreshSession(String refreshToken) async {
    final model = await _remote.refreshSession(refreshToken);
    return model.toEntity();
  }

  @override
  Future<UserProfile> fetchMe(String accessToken) async {
    final model = await _remote.fetchMe(accessToken);
    return model.toEntity();
  }
}
