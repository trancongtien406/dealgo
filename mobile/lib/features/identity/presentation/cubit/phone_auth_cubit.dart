import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/auth/token_store.dart';
import '../../../../core/network/api_exception.dart';
import '../../domain/params/create_phone_challenge_params.dart';
import '../../domain/params/verify_phone_params.dart';
import '../../domain/usecases/create_phone_challenge.dart';
import '../../domain/usecases/verify_phone_challenge.dart';
import 'auth_cubit.dart';

enum PhoneAuthPhase { challenge, verify, resend, mockDemo, passkey }

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
  const PhoneAuthVerifying({
    required this.phone,
    required this.challengeId,
  });

  final String phone;
  final String challengeId;
}

final class PhoneAuthResending extends PhoneAuthState {
  const PhoneAuthResending({
    required this.phone,
    required this.challengeId,
  });

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

final class PhoneAuthError extends PhoneAuthState {
  const PhoneAuthError({
    required this.error,
    required this.phase,
    this.phone,
    this.challengeId,
  });

  final ApiException error;
  final PhoneAuthPhase phase;
  final String? phone;
  final String? challengeId;
}

class PhoneAuthCubit extends Cubit<PhoneAuthState> {
  PhoneAuthCubit({
    required this._createPhoneChallenge,
    required this._verifyPhoneChallenge,
    required this.auth,
  }) : super(const PhoneAuthIdle());

  final CreatePhoneChallenge _createPhoneChallenge;
  final VerifyPhoneChallenge _verifyPhoneChallenge;
  final AuthCubit auth;

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
    emit(
      PhoneAuthResending(phone: phone, challengeId: previousChallengeId),
    );
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
      emit(
        PhoneAuthError(error: error, phase: PhoneAuthPhase.mockDemo),
      );
    }
  }

  Future<void> signInWithPasskey({bool isRegister = false}) async {
    final requestId = ++_requestId;
    emit(PhoneAuthPasskeySigningIn(isRegister: isRegister));
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
      emit(
        PhoneAuthError(error: error, phase: PhoneAuthPhase.passkey),
      );
    }
  }

  void clearError() {
    final current = state;
    if (current is! PhoneAuthError) {
      return;
    }
    final challengeId = current.challengeId;
    final phone = current.phone;
    if (challengeId != null && phone != null) {
      emit(PhoneAuthChallengeReady(phone: phone, challengeId: challengeId));
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
      state is PhoneAuthPasskeySigningIn;
}
