import '../entities/auth_method_policy.dart';
import '../entities/phone_challenge.dart';
import '../entities/user_profile.dart';
import '../entities/verified_session.dart';

abstract interface class IdentityRepository {
  Future<PhoneChallenge> createPhoneChallenge(String phone);

  Future<VerifiedSession> verifyPhoneChallenge({
    required String challengeId,
    required String code,
  });

  /// Starts email sign-up and returns the OTP challenge sent to [email].
  Future<PhoneChallenge> registerWithEmail({
    required String email,
    required String password,
    String? displayName,
  });

  Future<VerifiedSession> verifyEmailRegistration({
    required String challengeId,
    required String code,
  });

  Future<PhoneChallenge> resendEmailRegistration(String challengeId);

  Future<VerifiedSession> loginWithEmail({
    required String email,
    required String password,
  });

  /// Forgot password (DEC-PROD-045). The challenge answers alike for unknown emails.
  Future<PhoneChallenge> requestPasswordReset(String email);

  Future<PhoneChallenge> resendPasswordReset(String challengeId);

  Future<void> confirmPasswordReset({
    required String challengeId,
    required String code,
    required String newPassword,
  });

  Future<VerifiedSession> refreshSession(String refreshToken);

  Future<void> revokeSession(String accessToken);

  Future<UserProfile> fetchMe(String accessToken);

  Future<UserProfile> updateMe({
    required String accessToken,
    String? displayName,
    String? email,
    String? dateOfBirth,
    String? gender,
  });

  Future<String> uploadAvatar({
    required String accessToken,
    String? contentBase64,
    String? dataUrl,
    String? contentType,
  });

  Future<Map<String, Object?>> passkeyAuthenticationOptions();

  Future<VerifiedSession> passkeyAuthenticationVerify(
    Map<String, Object?> assertion,
  );

  Future<Map<String, Object?>> passkeySignupOptions();
  Future<VerifiedSession> passkeySignupVerify(Map<String, Object?> credential);

  Future<List<AuthMethodPolicy>> getAuthMethods();
}
