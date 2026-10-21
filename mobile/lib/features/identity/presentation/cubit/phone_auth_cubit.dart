import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/auth/token_store.dart';
import '../../../../core/network/api_exception.dart';
import '../../domain/params/create_phone_challenge_params.dart';
import '../../domain/params/verify_phone_params.dart';
import '../../domain/passkey_platform.dart';
import '../../domain/repositories/identity_repository.dart';
import '../../domain/usecases/create_phone_challenge.dart';
import '../../domain/usecases/verify_phone_challenge.dart';
import 'auth_cubit.dart';

enum PhoneAuthPhase {
  challenge,
  verify,
  resend,
  mockDemo,
  passkey,
  emailLogin,
  emailRegister,
  emailVerify,
  emailResend,
}

sealed class PhoneAuthState {
  const PhoneAuthState();
}

final class PhoneAuthIdle extends PhoneAuthState {
  const PhoneAuthIdle();
}

final class PhoneAuthSubmittingChallenge extends PhoneAuthState {
  const PhoneAuthSubmittingChallenge({required this.phone});

  final String phone;
}

final class PhoneAuthChallengeReady extends PhoneAuthState {
  const PhoneAuthChallengeReady({
    required this.phone,
    required this.challengeId,
  });

  final String phone;
  final String challengeId;
}

final class PhoneAuthVerifying extends PhoneAuthState {
  const PhoneAuthVerifying({required this.phone, required this.challengeId});

  final String phone;
  final String challengeId;
}

final class PhoneAuthResending extends PhoneAuthState {
  const PhoneAuthResending({required this.phone, required this.challengeId});

  final String phone;
  final String challengeId;
}

final class PhoneAuthMockSigningIn extends PhoneAuthState {
  const PhoneAuthMockSigningIn();
}

final class PhoneAuthPasskeySigningIn extends PhoneAuthState {
  const PhoneAuthPasskeySigningIn({this.isRegister = false});

  final bool isRegister;
}

final class PhoneAuthEmailSigningIn extends PhoneAuthState {
  const PhoneAuthEmailSigningIn({required this.isRegister});

  final bool isRegister;
}

/// Email sign-up code was sent; the account exists only after verification.
final class PhoneAuthEmailChallengeReady extends PhoneAuthState {
  const PhoneAuthEmailChallengeReady({
    required this.email,
    required this.challengeId,
  });

  final String email;
  final String challengeId;
}

final class PhoneAuthEmailVerifying extends PhoneAuthState {
  const PhoneAuthEmailVerifying({
    required this.email,
    required this.challengeId,
  });

  final String email;
  final String challengeId;
}

final class PhoneAuthEmailResending extends PhoneAuthState {
  const PhoneAuthEmailResending({
    required this.email,
    required this.challengeId,
  });

  final String email;
  final String challengeId;
}

final class PhoneAuthError extends PhoneAuthState {
  const PhoneAuthError({
    required this.error,
    required this.phase,
    this.phone,
    this.email,
    this.challengeId,
  });

  final ApiException error;
  final PhoneAuthPhase phase;
  final String? phone;

  /// Set for email sign-up OTP errors so [PhoneAuthCubit.clearError] can return to entry.
  final String? email;
  final String? challengeId;
}

class PhoneAuthCubit extends Cubit<PhoneAuthState> {
  PhoneAuthCubit({
    required CreatePhoneChallenge createPhoneChallenge,
    required VerifyPhoneChallenge verifyPhoneChallenge,
    required this.auth,
    required IdentityRepository identityRepository,
    required PasskeyPlatform passkeyPlatform,
  }) : _createPhoneChallenge = createPhoneChallenge,
       _verifyPhoneChallenge = verifyPhoneChallenge,
       _identityRepository = identityRepository,
       _passkeyPlatform = passkeyPlatform,
       super(const PhoneAuthIdle());

  final CreatePhoneChallenge _createPhoneChallenge;
  final VerifyPhoneChallenge _verifyPhoneChallenge;
  final AuthCubit auth;
  final IdentityRepository _identityRepository;
  final PasskeyPlatform _passkeyPlatform;

  var _requestId = 0;

  Future<void> createPhoneChallenge(String phone) async {
    final requestId = ++_requestId;
    emit(PhoneAuthSubmittingChallenge(phone: phone));
    try {
      final challenge = await _createPhoneChallenge(
        CreatePhoneChallengeParams(phone),
      );
      if (isClosed || requestId != _requestId) {
        return;
      }
      emit(
        PhoneAuthChallengeReady(
          phone: phone,
          challengeId: challenge.challengeId,
        ),
      );
    } on ApiException catch (error) {
      if (isClosed || requestId != _requestId) {
        return;
      }
      emit(
        PhoneAuthError(
          error: error,
          phase: PhoneAuthPhase.challenge,
          phone: phone,
        ),
      );
    }
  }

  Future<void> verifyOtp({
    required String challengeId,
    required String phone,
    required String code,
  }) async {
    final requestId = ++_requestId;
    emit(PhoneAuthVerifying(phone: phone, challengeId: challengeId));
    try {
      final session = await _verifyPhoneChallenge(
        VerifyPhoneParams(challengeId: challengeId, code: code),
      );
      if (isClosed || requestId != _requestId) {
        return;
      }
      await auth.completeSignIn(
        StoredTokens(
          accessToken: session.accessToken,
          refreshToken: session.refreshToken,
        ),
      );
    } on ApiException catch (error) {
      if (isClosed || requestId != _requestId) {
        return;
      }
      emit(
        PhoneAuthError(
          error: error,
          phase: PhoneAuthPhase.verify,
          phone: phone,
          challengeId: challengeId,
        ),
      );
    }
  }

  Future<void> resendChallenge({
    required String phone,
    required String previousChallengeId,
  }) async {
    final requestId = ++_requestId;
    emit(PhoneAuthResending(phone: phone, challengeId: previousChallengeId));
    try {
      final challenge = await _createPhoneChallenge(
        CreatePhoneChallengeParams(phone),
      );
      if (isClosed || requestId != _requestId) {
        return;
      }
      emit(
        PhoneAuthChallengeReady(
          phone: phone,
          challengeId: challenge.challengeId,
        ),
      );
    } on ApiException catch (error) {
      if (isClosed || requestId != _requestId) {
        return;
      }
      emit(
        PhoneAuthError(
          error: error,
          phase: PhoneAuthPhase.resend,
          phone: phone,
          challengeId: previousChallengeId,
        ),
      );
    }
  }

  Future<void> enterMockDemo() async {
    final requestId = ++_requestId;
    emit(const PhoneAuthMockSigningIn());
    try {
      const phone = '+84900000000';
      final challenge = await _createPhoneChallenge(
        const CreatePhoneChallengeParams(phone),
      );
      final session = await _verifyPhoneChallenge(
        VerifyPhoneParams(challengeId: challenge.challengeId, code: '000000'),
      );
      if (isClosed || requestId != _requestId) {
        return;
      }
      await auth.completeSignIn(
        StoredTokens(
          accessToken: session.accessToken,
          refreshToken: session.refreshToken,
        ),
      );
    } on ApiException catch (error) {
      if (isClosed || requestId != _requestId) {
        return;
      }
      emit(PhoneAuthError(error: error, phase: PhoneAuthPhase.mockDemo));
    }
  }

  Future<void> loginWithEmail({
    required String email,
    required String password,
  }) async {
    final requestId = ++_requestId;
    emit(const PhoneAuthEmailSigningIn(isRegister: false));
    try {
      final session = await _identityRepository.loginWithEmail(
        email: email.trim(),
        password: password,
      );
      if (isClosed || requestId != _requestId) {
        return;
      }
      await auth.completeSignIn(
        StoredTokens(
          accessToken: session.accessToken,
          refreshToken: session.refreshToken,
        ),
      );
    } on ApiException catch (error) {
      if (isClosed || requestId != _requestId) {
        return;
      }
      // Right password on a never-verified email: the server mailed an activation
      // code, so continue on the email OTP screen instead of showing an error.
      final activationId = _activationChallengeId(error);
      if (activationId != null) {
        emit(
          PhoneAuthEmailChallengeReady(
            email: email.trim(),
            challengeId: activationId,
          ),
        );
        return;
      }
      emit(PhoneAuthError(error: error, phase: PhoneAuthPhase.emailLogin));
    }
  }

  String? _activationChallengeId(ApiException error) {
    if (error.statusCode != 403 ||
        error.errorCode != 'AUTH_EMAIL_NOT_VERIFIED') {
      return null;
    }
    final id = error.details?['challengeId'];
    return id is String && id.isNotEmpty ? id : null;
  }

  Future<void> registerWithEmail({
    required String email,
    required String password,
    String? displayName,
  }) async {
    final requestId = ++_requestId;
    final trimmedEmail = email.trim();
    emit(const PhoneAuthEmailSigningIn(isRegister: true));
    try {
      final challenge = await _identityRepository.registerWithEmail(
        email: trimmedEmail,
        password: password,
        displayName: displayName,
      );
      if (isClosed || requestId != _requestId) {
        return;
      }
      emit(
        PhoneAuthEmailChallengeReady(
          email: trimmedEmail,
          challengeId: challenge.challengeId,
        ),
      );
    } on ApiException catch (error) {
      if (isClosed || requestId != _requestId) {
        return;
      }
      emit(PhoneAuthError(error: error, phase: PhoneAuthPhase.emailRegister));
    }
  }

  Future<void> verifyEmailRegistration({
    required String challengeId,
    required String email,
    required String code,
  }) async {
    final requestId = ++_requestId;
    emit(PhoneAuthEmailVerifying(email: email, challengeId: challengeId));
    try {
      final session = await _identityRepository.verifyEmailRegistration(
        challengeId: challengeId,
        code: code,
      );
      if (isClosed || requestId != _requestId) {
        return;
      }
      await auth.completeSignIn(
        StoredTokens(
          accessToken: session.accessToken,
          refreshToken: session.refreshToken,
        ),
      );
    } on ApiException catch (error) {
      if (isClosed || requestId != _requestId) {
        return;
      }
      emit(
        PhoneAuthError(
          error: error,
          phase: PhoneAuthPhase.emailVerify,
          email: email,
          challengeId: challengeId,
        ),
      );
    }
  }

  Future<void> resendEmailRegistration({
    required String email,
    required String challengeId,
  }) async {
    final requestId = ++_requestId;
    emit(PhoneAuthEmailResending(email: email, challengeId: challengeId));
    try {
      final challenge = await _identityRepository.resendEmailRegistration(
        challengeId,
      );
      if (isClosed || requestId != _requestId) {
        return;
      }
      emit(
        PhoneAuthEmailChallengeReady(
          email: email,
          challengeId: challenge.challengeId,
        ),
      );
    } on ApiException catch (error) {
      if (isClosed || requestId != _requestId) {
        return;
      }
      emit(
        PhoneAuthError(
          error: error,
          phase: PhoneAuthPhase.emailResend,
          email: email,
          challengeId: challengeId,
        ),
      );
    }
  }

  /// Identifierless passkey sign-in. The authenticator selects a discoverable credential.
  Future<void> signInWithPasskey() async {
    final requestId = ++_requestId;
    emit(const PhoneAuthPasskeySigningIn());
    try {
      final options = await _identityRepository.passkeyAuthenticationOptions();
      final ceremonyId = options['ceremonyId'];
      if (ceremonyId is! String) {
        throw const FormatException('Missing ceremonyId');
      }
      final platformOptions = Map<String, Object?>.from(options)
        ..remove('ceremonyId');
      final assertion = await _passkeyPlatform.authenticate(platformOptions)
        ..['ceremonyId'] = ceremonyId;
      final session = await _identityRepository.passkeyAuthenticationVerify(
        assertion,
      );
      if (isClosed || requestId != _requestId) {
        return;
      }
      await auth.completeSignIn(
        StoredTokens(
          accessToken: session.accessToken,
          refreshToken: session.refreshToken,
        ),
      );
    } on ApiException catch (error) {
      if (isClosed || requestId != _requestId) {
        return;
      }
      emit(PhoneAuthError(error: error, phase: PhoneAuthPhase.passkey));
    } on Object catch (error) {
      if (isClosed || requestId != _requestId) {
        return;
      }
      emit(
        PhoneAuthError(
          error: ApiException(
            statusCode: 0,
            errorCode: 'PASSKEY_UNAVAILABLE',
            message: error.toString(),
          ),
          phase: PhoneAuthPhase.passkey,
        ),
      );
    }
  }

  Future<void> signUpWithPasskey() async {
    final requestId = ++_requestId;
    emit(const PhoneAuthPasskeySigningIn(isRegister: true));
    try {
      final options = await _identityRepository.passkeySignupOptions();
      final ceremonyId = options['ceremonyId'];
      if (ceremonyId is! String) {
        throw const FormatException('Missing ceremonyId');
      }
      final platformOptions = Map<String, Object?>.from(options)
        ..remove('ceremonyId');
      final credential = await _passkeyPlatform.register(platformOptions)
        ..['ceremonyId'] = ceremonyId;
      final session = await _identityRepository.passkeySignupVerify(credential);
      if (isClosed || requestId != _requestId) {
        return;
      }
      await auth.completeSignIn(
        StoredTokens(
          accessToken: session.accessToken,
          refreshToken: session.refreshToken,
        ),
      );
    } on ApiException catch (error) {
      if (!isClosed && requestId == _requestId) {
        emit(PhoneAuthError(error: error, phase: PhoneAuthPhase.passkey));
      }
    } on Object catch (error) {
      if (!isClosed && requestId == _requestId) {
        emit(
          PhoneAuthError(
            error: ApiException(
              statusCode: 0,
              errorCode: 'PASSKEY_UNAVAILABLE',
              message: error.toString(),
            ),
            phase: PhoneAuthPhase.passkey,
          ),
        );
      }
    }
  }

  void clearError() {
    final current = state;
    if (current is! PhoneAuthError) {
      return;
    }
    final challengeId = current.challengeId;
    final phone = current.phone;
    final email = current.email;
    if (challengeId != null && phone != null) {
      emit(PhoneAuthChallengeReady(phone: phone, challengeId: challengeId));
      return;
    }
    if (challengeId != null && email != null) {
      emit(
        PhoneAuthEmailChallengeReady(email: email, challengeId: challengeId),
      );
      return;
    }
    emit(const PhoneAuthIdle());
  }

  void reset() {
    _requestId++;
    emit(const PhoneAuthIdle());
  }
}

bool isPhoneAuthBusy(PhoneAuthState state) {
  return state is PhoneAuthSubmittingChallenge ||
      state is PhoneAuthVerifying ||
      state is PhoneAuthResending ||
      state is PhoneAuthMockSigningIn ||
      state is PhoneAuthPasskeySigningIn ||
      state is PhoneAuthEmailSigningIn ||
      state is PhoneAuthEmailVerifying ||
      state is PhoneAuthEmailResending;
}
