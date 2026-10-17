import '../models/phone_challenge_model.dart';
import '../models/user_profile_model.dart';
import '../models/verified_session_model.dart';

/// Remote identity API contract (phone challenge / session / me).
abstract interface class IdentityRemoteDataSource {
  Future<PhoneChallengeModel> createPhoneChallenge(String phone);

  Future<VerifiedSessionModel> verifyPhoneChallenge({
    required String challengeId,
    required String code,
  });

  Future<VerifiedSessionModel> refreshSession(String refreshToken);

  Future<UserProfileModel> fetchMe(String accessToken);
}

/// Backward-compatible alias used by mocks, tests, and DI overrides.
typedef IdentityClient = IdentityRemoteDataSource;
