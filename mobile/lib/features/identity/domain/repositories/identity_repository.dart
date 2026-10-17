import '../entities/phone_challenge.dart';
import '../entities/user_profile.dart';
import '../entities/verified_session.dart';

abstract interface class IdentityRepository {
  Future<PhoneChallenge> createPhoneChallenge(String phone);

  Future<VerifiedSession> verifyPhoneChallenge({
    required String challengeId,
    required String code,
  });

  Future<VerifiedSession> refreshSession(String refreshToken);

  Future<UserProfile> fetchMe(String accessToken);
}
