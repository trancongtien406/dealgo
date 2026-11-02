import '../models/auth_method_policy_model.dart';
import '../models/email_verification_model.dart';
import '../models/phone_challenge_model.dart';
import '../models/user_profile_model.dart';
import '../models/verified_session_model.dart';

/// Remote identity API contract (phone / passkey / session / me / auth methods).
abstract interface class IdentityRemoteDataSource {
  Future<PhoneChallengeModel> createPhoneChallenge(String phone);

  Future<VerifiedSessionModel> verifyPhoneChallenge({
    required String challengeId,
    required String code,
  });

  /// Starts email sign-up; the account exists only after [verifyEmailRegistration].
  /// The challenge shape (id + expiry) is shared with phone OTP.
  Future<PhoneChallengeModel> registerWithEmail({
    required String email,
    required String password,
    String? displayName,
  });

  Future<VerifiedSessionModel> verifyEmailRegistration({
    required String challengeId,
    required String code,
  });

  Future<PhoneChallengeModel> resendEmailRegistration(String challengeId);

  Future<VerifiedSessionModel> loginWithEmail({
    required String email,
    required String password,
  });

  /// Forgot password (DEC-PROD-045): same challenge shape for every address.
  Future<PhoneChallengeModel> requestPasswordReset(String email);

  Future<PhoneChallengeModel> resendPasswordReset(String challengeId);

  Future<void> confirmPasswordReset({
    required String challengeId,
    required String code,
    required String newPassword,
  });

  Future<VerifiedSessionModel> refreshSession(String refreshToken);

  Future<void> revokeSession(String accessToken);

  Future<UserProfileModel> fetchMe(String accessToken);

  Future<UserProfileModel> updateMe({
    required String accessToken,
    String? displayName,
    String? email,
    String? dateOfBirth,
    String? gender,
    String? contactPhone,
  });

  Future<String> uploadAvatar({
    required String accessToken,
    String? contentBase64,
    String? dataUrl,
    String? contentType,
  });

  /// Mails a 6-digit code to [email]. Inside the resend cooldown the server
  /// returns the live verification without mailing again.
  Future<EmailVerificationModel> requestEmailVerification({
    required String accessToken,
    required String email,
  });

  Future<void> confirmEmailVerification({
    required String verificationId,
    required String code,
  });

  Future<Map<String, Object?>> passkeyAuthenticationOptions();

  Future<VerifiedSessionModel> passkeyAuthenticationVerify(
    Map<String, Object?> assertion,
  );
  Future<Map<String, Object?>> passkeySignupOptions();
  Future<VerifiedSessionModel> passkeySignupVerify(
    Map<String, Object?> credential,
  );

  Future<List<AuthMethodPolicyModel>> getAuthMethods();
}

/// Backward-compatible alias used by mocks, tests, and DI overrides.
typedef IdentityClient = IdentityRemoteDataSource;
