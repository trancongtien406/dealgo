import '../../domain/entities/auth_method_policy.dart';
import '../../domain/entities/email_verification.dart';
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
  Future<PhoneChallenge> registerWithEmail({
    required String email,
    required String password,
    String? displayName,
  }) async {
    final model = await _remote.registerWithEmail(
      email: email,
      password: password,
      displayName: displayName,
    );
    return model.toEntity();
  }

  @override
  Future<VerifiedSession> verifyEmailRegistration({
    required String challengeId,
    required String code,
  }) async {
    final model = await _remote.verifyEmailRegistration(
      challengeId: challengeId,
      code: code,
    );
    return model.toEntity();
  }

  @override
  Future<PhoneChallenge> resendEmailRegistration(String challengeId) async {
    final model = await _remote.resendEmailRegistration(challengeId);
    return model.toEntity();
  }

  @override
  Future<PhoneChallenge> requestPasswordReset(String email) async {
    final model = await _remote.requestPasswordReset(email);
    return model.toEntity();
  }

  @override
  Future<PhoneChallenge> resendPasswordReset(String challengeId) async {
    final model = await _remote.resendPasswordReset(challengeId);
    return model.toEntity();
  }

  @override
  Future<void> confirmPasswordReset({
    required String challengeId,
    required String code,
    required String newPassword,
  }) {
    return _remote.confirmPasswordReset(
      challengeId: challengeId,
      code: code,
      newPassword: newPassword,
    );
  }

  @override
  Future<VerifiedSession> loginWithEmail({
    required String email,
    required String password,
  }) async {
    final model = await _remote.loginWithEmail(
      email: email,
      password: password,
    );
    return model.toEntity();
  }

  @override
  Future<VerifiedSession> refreshSession(String refreshToken) async {
    final model = await _remote.refreshSession(refreshToken);
    return model.toEntity();
  }

  @override
  Future<void> revokeSession(String accessToken) {
    return _remote.revokeSession(accessToken);
  }

  @override
  Future<UserProfile> fetchMe(String accessToken) async {
    final model = await _remote.fetchMe(accessToken);
    return model.toEntity();
  }

  @override
  Future<UserProfile> updateMe({
    required String accessToken,
    String? displayName,
    String? email,
    String? dateOfBirth,
    String? gender,
    String? contactPhone,
  }) async {
    final model = await _remote.updateMe(
      accessToken: accessToken,
      displayName: displayName,
      email: email,
      dateOfBirth: dateOfBirth,
      gender: gender,
      contactPhone: contactPhone,
    );
    return model.toEntity();
  }

  @override
  Future<String> uploadAvatar({
    required String accessToken,
    String? contentBase64,
    String? dataUrl,
    String? contentType,
  }) {
    return _remote.uploadAvatar(
      accessToken: accessToken,
      contentBase64: contentBase64,
      dataUrl: dataUrl,
      contentType: contentType,
    );
  }

  @override
  Future<EmailVerification> requestEmailVerification({
    required String accessToken,
    required String email,
  }) async {
    final normalized = email.trim().toLowerCase();
    final model = await _remote.requestEmailVerification(
      accessToken: accessToken,
      email: normalized,
    );
    return model.toEntity(normalized);
  }

  @override
  Future<void> confirmEmailVerification({
    required String verificationId,
    required String code,
  }) {
    return _remote.confirmEmailVerification(
      verificationId: verificationId,
      code: code,
    );
  }

  @override
  Future<Map<String, Object?>> passkeyAuthenticationOptions() =>
      _remote.passkeyAuthenticationOptions();

  @override
  Future<VerifiedSession> passkeyAuthenticationVerify(
    Map<String, Object?> assertion,
  ) async {
    final model = await _remote.passkeyAuthenticationVerify(assertion);
    return model.toEntity();
  }

  @override
  Future<Map<String, Object?>> passkeySignupOptions() =>
      _remote.passkeySignupOptions();

  @override
  Future<VerifiedSession> passkeySignupVerify(
    Map<String, Object?> credential,
  ) async {
    final model = await _remote.passkeySignupVerify(credential);
    return model.toEntity();
  }

  @override
  Future<List<AuthMethodPolicy>> getAuthMethods() async {
    return _remote.getAuthMethods();
  }
}
