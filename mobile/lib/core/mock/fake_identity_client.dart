import 'dart:async';

import '../../features/identity/data/datasources/identity_remote_datasource.dart';
import '../../features/identity/data/models/auth_method_policy_model.dart';
import '../../features/identity/data/models/phone_challenge_model.dart';
import '../../features/identity/data/models/user_profile_model.dart';
import '../../features/identity/data/models/verified_session_model.dart';
import '../../features/identity/domain/entities/auth_method_policy.dart';
import '../../features/identity/domain/entities/user_profile.dart';
import '../network/api_exception.dart';

class FakeIdentityClient implements IdentityClient {
  FakeIdentityClient({UserProfile? profile, this.verifyError})
    : profile = profile ?? customerProfile;

  UserProfile profile;
  ApiException? verifyError;
  ApiException? passkeyError;
  Completer<void>? challengeGate;
  final List<String> challengedPhones = [];
  final List<({String challengeId, String code})> verifyCalls = [];
  final List<String> refreshCalls = [];
  final List<String> revokeCalls = [];
  final List<bool> passkeyOptionCalls = [];
  final List<Map<String, Object?>> passkeyVerifyCalls = [];
  final List<Map<String, Object?>> passkeySignupVerifyCalls = [];
  final List<Map<String, Object?>> updateMeCalls = [];
  final List<Map<String, Object?>> avatarUploads = [];
  final Map<String, String> _emailPasswords = {};
  final List<({String email, String password, String? displayName})>
  registerEmailCalls = [];
  final List<({String email, String password})> loginEmailCalls = [];
  final List<({String challengeId, String code})> verifyEmailCalls = [];
  final List<String> resendEmailCalls = [];
  final Map<String, ({String email, String password, String? displayName})>
  _pendingEmailSignups = {};
  final Map<String, String> _unverifiedEmailPasswords = {};
  final Map<String, String> _pendingEmailActivations = {};
  int _activationCount = 0;
  ApiException? emailAuthError;
  ApiException? emailVerifyError;
  ApiException? emailResendError;
  ApiException? passwordResetError;
  final List<String> passwordResetRequests = [];
  final List<String> passwordResetResends = [];
  final List<({String challengeId, String code, String newPassword})>
  passwordResetConfirms = [];
  final Map<String, String> _pendingPasswordResets = {};
  int _passwordResetCount = 0;

  /// Code the fake "emails" for every reset challenge.
  static const passwordResetCode = '246810';

  /// Seeds a verified email+password account (login works without OTP).
  void seedEmailAccount(String email, String password) {
    _emailPasswords[_normalizeEmail(email)] = password;
  }

  String _normalizeEmail(String email) => email.trim().toLowerCase();

  /// Seeds an account created before OTP sign-up: login with the right password
  /// answers 403 AUTH_EMAIL_NOT_VERIFIED with an activation challenge.
  void seedUnverifiedEmailAccount(String email, String password) {
    _unverifiedEmailPasswords[_normalizeEmail(email)] = password;
  }

  @override
  Future<PhoneChallengeModel> createPhoneChallenge(String phone) async {
    challengedPhones.add(phone);
    final gate = challengeGate;
    if (gate != null) {
      await gate.future;
    }
    return const PhoneChallengeModel(
      challengeId: 'challenge-1',
      expiresAt: '2026-10-13T16:05:00.000Z',
    );
  }

  @override
  Future<VerifiedSessionModel> verifyPhoneChallenge({
    required String challengeId,
    required String code,
  }) async {
    verifyCalls.add((challengeId: challengeId, code: code));
    final error = verifyError;
    if (error != null) {
      throw error;
    }
    return const VerifiedSessionModel(
      accessToken: 'access-token',
      refreshToken: 'refresh-token',
      expiresIn: 900,
    );
  }

  /// Mirrors the server: an already-registered email still gets a challenge,
  /// but that challenge can never be verified.
  @override
  Future<PhoneChallengeModel> registerWithEmail({
    required String email,
    required String password,
    String? displayName,
  }) async {
    final normalized = _normalizeEmail(email);
    registerEmailCalls.add((
      email: normalized,
      password: password,
      displayName: displayName,
    ));
    final error = emailAuthError;
    if (error != null) {
      throw error;
    }
    final challengeId = 'email-challenge-${registerEmailCalls.length}';
    if (!_emailPasswords.containsKey(normalized)) {
      _pendingEmailSignups[challengeId] = (
        email: normalized,
        password: password,
        displayName: displayName,
      );
    }
    return PhoneChallengeModel(
      challengeId: challengeId,
      expiresAt: '2026-10-13T16:10:00.000Z',
    );
  }

  @override
  Future<VerifiedSessionModel> verifyEmailRegistration({
    required String challengeId,
    required String code,
  }) async {
    verifyEmailCalls.add((challengeId: challengeId, code: code));
    final error = emailVerifyError;
    if (error != null) {
      throw error;
    }
    final activated = _pendingEmailActivations.remove(challengeId);
    if (activated != null) {
      _emailPasswords[activated] = _unverifiedEmailPasswords.remove(activated)!;
      profile = profile.copyWith(
        email: activated,
        emailVerifiedAt: '2026-10-13T16:00:00.000Z',
      );
      return const VerifiedSessionModel(
        accessToken: 'access-token',
        refreshToken: 'refresh-token',
        expiresIn: 900,
      );
    }
    final pending = _pendingEmailSignups.remove(challengeId);
    if (pending == null) {
      throw const ApiException(
        statusCode: 401,
        errorCode: 'AUTH_CODE_INVALID',
        message: 'Verification code is invalid',
      );
    }
    final normalized = pending.email;
    final displayName = pending.displayName;
    _emailPasswords[normalized] = pending.password;
    final trimmedName = displayName?.trim();
    final resolvedName = (trimmedName != null && trimmedName.isNotEmpty)
        ? trimmedName
        : (normalized.split('@').first.isNotEmpty
              ? normalized.split('@').first
              : normalized);
    profile = profile.copyWith(
      email: normalized,
      displayName: resolvedName,
      emailVerifiedAt: '2026-10-13T16:00:00.000Z',
      needsProfileSetup:
          resolvedName.trim().isEmpty ||
          resolvedName.trim().toLowerCase() == 'dealgo user',
    );
    return const VerifiedSessionModel(
      accessToken: 'access-token',
      refreshToken: 'refresh-token',
      expiresIn: 900,
    );
  }

  @override
  Future<PhoneChallengeModel> resendEmailRegistration(
    String challengeId,
  ) async {
    resendEmailCalls.add(challengeId);
    final error = emailResendError;
    if (error != null) {
      throw error;
    }
    return PhoneChallengeModel(
      challengeId: challengeId,
      expiresAt: '2026-10-13T16:20:00.000Z',
    );
  }

  @override
  Future<PhoneChallengeModel> requestPasswordReset(String email) async {
    final normalized = _normalizeEmail(email);
    passwordResetRequests.add(normalized);
    final error = passwordResetError;
    if (error != null) {
      throw error;
    }
    _passwordResetCount += 1;
    final challengeId = 'password-reset-$_passwordResetCount';
    _pendingPasswordResets[challengeId] = normalized;
    return PhoneChallengeModel(
      challengeId: challengeId,
      expiresAt: '2026-10-13T16:10:00.000Z',
    );
  }

  @override
  Future<PhoneChallengeModel> resendPasswordReset(String challengeId) async {
    passwordResetResends.add(challengeId);
    return PhoneChallengeModel(
      challengeId: challengeId,
      expiresAt: '2026-10-13T16:20:00.000Z',
    );
  }

  @override
  Future<void> confirmPasswordReset({
    required String challengeId,
    required String code,
    required String newPassword,
  }) async {
    passwordResetConfirms.add((
      challengeId: challengeId,
      code: code,
      newPassword: newPassword,
    ));
    final email = _pendingPasswordResets[challengeId];
    if (email == null ||
        code != passwordResetCode ||
        !_emailPasswords.containsKey(email)) {
      throw const ApiException(
        statusCode: 401,
        errorCode: 'AUTH_CODE_INVALID',
        message: 'Reset code is invalid',
      );
    }
    _pendingPasswordResets.remove(challengeId);
    _emailPasswords[email] = newPassword;
  }

  @override
  Future<VerifiedSessionModel> loginWithEmail({
    required String email,
    required String password,
  }) async {
    final normalized = _normalizeEmail(email);
    loginEmailCalls.add((email: normalized, password: password));
    final error = emailAuthError;
    if (error != null) {
      throw error;
    }
    final unverified = _unverifiedEmailPasswords[normalized];
    if (unverified != null && unverified == password) {
      _activationCount += 1;
      final challengeId = 'email-activation-$_activationCount';
      _pendingEmailActivations[challengeId] = normalized;
      throw ApiException(
        statusCode: 403,
        errorCode: 'AUTH_EMAIL_NOT_VERIFIED',
        message: 'Email address is not verified; a verification code was sent',
        details: {
          'challengeId': challengeId,
          'expiresAt': '2026-10-13T16:10:00.000Z',
          'resendAvailableAt': '2026-10-13T16:01:00.000Z',
        },
      );
    }
    final stored = _emailPasswords[normalized];
    if (stored == null || stored != password) {
      throw const ApiException(
        statusCode: 401,
        errorCode: 'AUTH_INVALID_CREDENTIALS',
        message: 'Invalid email or password',
      );
    }
    profile = profile.copyWith(email: normalized);
    return const VerifiedSessionModel(
      accessToken: 'access-token',
      refreshToken: 'refresh-token',
      expiresIn: 900,
    );
  }

  @override
  Future<VerifiedSessionModel> refreshSession(String refreshToken) async {
    refreshCalls.add(refreshToken);
    return VerifiedSessionModel(
      accessToken: 'access-token-refreshed',
      refreshToken: '$refreshToken-rotated',
      expiresIn: 900,
    );
  }

  @override
  Future<void> revokeSession(String accessToken) async {
    revokeCalls.add(accessToken);
  }

  List<AuthMethodPolicyModel> authMethods = const [
    AuthMethodPolicyModel(method: AuthMethodPolicy.passkey, enabled: true),
    AuthMethodPolicyModel(method: AuthMethodPolicy.phoneSms, enabled: true),
    AuthMethodPolicyModel(method: AuthMethodPolicy.email, enabled: true),
  ];

  @override
  Future<UserProfileModel> fetchMe(String accessToken) async {
    return UserProfileModel.fromEntity(profile);
  }

  @override
  Future<UserProfileModel> updateMe({
    required String accessToken,
    String? displayName,
    String? email,
    String? dateOfBirth,
    String? gender,
    String? contactPhone,
  }) async {
    updateMeCalls.add({
      'contactPhone': contactPhone,
      'displayName': displayName,
      'email': email,
      'dateOfBirth': dateOfBirth,
      'gender': gender,
    });
    final nextName = displayName?.trim() ?? profile.displayName;
    profile = profile.copyWith(
      displayName: nextName,
      email: email ?? profile.email,
      dateOfBirth: dateOfBirth ?? profile.dateOfBirth,
      gender: gender ?? profile.gender,
      contactPhone: contactPhone ?? profile.contactPhone,
    );
    profile = profile.copyWith(
      needsProfileSetup:
          nextName.trim().isEmpty ||
          nextName.trim().toLowerCase() == 'dealgo user' ||
          !profile.hasAnyPhone,
    );
    return UserProfileModel.fromEntity(profile);
  }

  @override
  Future<String> uploadAvatar({
    required String accessToken,
    String? contentBase64,
    String? dataUrl,
    String? contentType,
  }) async {
    avatarUploads.add({
      'contentBase64': contentBase64,
      'dataUrl': dataUrl,
      'contentType': contentType,
    });
    final url = 'mock://avatar/${profile.id}/fake';
    profile = profile.copyWith(avatarUrl: url);
    return url;
  }

  @override
  Future<Map<String, Object?>> passkeyAuthenticationOptions() async {
    passkeyOptionCalls.add(true);
    final error = passkeyError;
    if (error != null) {
      throw error;
    }
    return {
      'ceremonyId': '00000000-0000-4000-8000-000000000001',
      'challenge': 'fake-challenge',
      'timeout': 60000,
      'rpId': 'localhost',
      'allowCredentials': [
        {'id': 'fake-passkey-credential', 'type': 'public-key'},
      ],
      'userVerification': 'required',
    };
  }

  @override
  Future<Map<String, Object?>> passkeySignupOptions() async => {
    'ceremonyId': '00000000-0000-4000-8000-000000000002',
    'challenge': 'fake-signup-challenge',
    'rp': <String, Object?>{'id': 'localhost', 'name': 'DealGo'},
    'user': <String, Object?>{
      'id': 'fake-user-id',
      'name': 'New DealGo account',
      'displayName': 'DealGo user',
    },
    'pubKeyCredParams': <Map<String, Object?>>[
      {'type': 'public-key', 'alg': -7},
    ],
  };

  @override
  Future<VerifiedSessionModel> passkeySignupVerify(
    Map<String, Object?> credential,
  ) async {
    passkeySignupVerifyCalls.add(Map<String, Object?>.from(credential));
    return const VerifiedSessionModel(
      accessToken: 'access-token',
      refreshToken: 'refresh-token',
      expiresIn: 900,
    );
  }

  @override
  Future<VerifiedSessionModel> passkeyAuthenticationVerify(
    Map<String, Object?> assertion,
  ) async {
    passkeyVerifyCalls.add(Map<String, Object?>.from(assertion));
    final error = passkeyError ?? verifyError;
    if (error != null) {
      throw error;
    }
    return const VerifiedSessionModel(
      accessToken: 'access-token',
      refreshToken: 'refresh-token',
      expiresIn: 900,
    );
  }

  @override
  Future<List<AuthMethodPolicyModel>> getAuthMethods() async {
    return authMethods;
  }
}

const customerProfile = UserProfile(
  id: 'user-1',
  phone: '+84911111111',
  email: null,
  displayName: 'Nguyễn Văn A',
  phoneVerifiedAt: '2026-10-13T16:00:00.000Z',
  emailVerifiedAt: null,
  needsProfileSetup: false,
  grants: [RoleGrant(role: 'CUSTOMER', status: 'ACTIVE')],
);

const needsProfileSetupProfile = UserProfile(
  id: 'user-new',
  phone: '+84911111111',
  email: null,
  displayName: 'DealGo User',
  phoneVerifiedAt: '2026-10-13T16:00:00.000Z',
  emailVerifiedAt: null,
  needsProfileSetup: true,
  grants: [RoleGrant(role: 'CUSTOMER', status: 'ACTIVE')],
);

const sandboxProfile = UserProfile(
  id: 'user-2',
  phone: '+84922222222',
  email: null,
  displayName: 'Sandbox',
  phoneVerifiedAt: '2026-10-13T16:00:00.000Z',
  emailVerifiedAt: null,
  needsProfileSetup: false,
  grants: [],
);

const multiRoleProfile = UserProfile(
  id: 'user-3',
  phone: '+84987654321',
  email: null,
  displayName: 'Multi Role',
  phoneVerifiedAt: '2026-10-13T16:00:00.000Z',
  emailVerifiedAt: null,
  needsProfileSetup: false,
  grants: [
    RoleGrant(role: 'DRIVER', status: 'ACTIVE'),
    RoleGrant(role: 'MERCHANT', status: 'ACTIVE'),
    RoleGrant(role: 'CUSTOMER', status: 'ACTIVE'),
    RoleGrant(role: 'OPS', status: 'ACTIVE'),
    RoleGrant(role: 'CUSTOMER', status: 'PENDING'),
  ],
);

const demoMultiRoleProfile = UserProfile(
  id: 'demo-user',
  phone: '+84900000000',
  email: 'demo@dealgo.local',
  displayName: 'Demo User',
  phoneVerifiedAt: '2026-10-13T16:00:00.000Z',
  emailVerifiedAt: '2026-10-13T16:00:00.000Z',
  needsProfileSetup: false,
  grants: [
    RoleGrant(role: 'CUSTOMER', status: 'ACTIVE'),
    RoleGrant(role: 'DRIVER', status: 'ACTIVE'),
    RoleGrant(role: 'MERCHANT', status: 'ACTIVE'),
  ],
);

const pendingPartnerProfile = UserProfile(
  id: 'pending-partner',
  phone: '+84933333333',
  email: null,
  displayName: 'Pending Partner',
  phoneVerifiedAt: '2026-10-13T16:00:00.000Z',
  emailVerifiedAt: null,
  needsProfileSetup: false,
  grants: [
    RoleGrant(role: 'CUSTOMER', status: 'ACTIVE'),
    RoleGrant(role: 'DRIVER', status: 'PENDING'),
    RoleGrant(role: 'MERCHANT', status: 'PENDING'),
  ],
);
