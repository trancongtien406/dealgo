import 'package:dealgo/core/network/api_exception.dart';
import 'package:dealgo/features/identity/data/repositories/identity_repository_impl.dart';
import 'package:dealgo/features/identity/domain/entities/auth_state.dart';
import 'package:dealgo/features/identity/domain/passkey_platform.dart';
import 'package:dealgo/features/identity/domain/usecases/create_phone_challenge.dart';
import 'package:dealgo/features/identity/domain/usecases/fetch_me.dart';
import 'package:dealgo/features/identity/domain/usecases/verify_phone_challenge.dart';
import 'package:dealgo/features/identity/presentation/cubit/auth_cubit.dart';
import 'package:dealgo/features/identity/presentation/cubit/phone_auth_cubit.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/fake_identity_client.dart';
import 'support/memory_token_store.dart';

void main() {
  late FakeIdentityClient client;
  late AuthCubit auth;
  late PhoneAuthCubit cubit;
  late FakePasskeyPlatform passkeys;

  setUp(() {
    client = FakeIdentityClient(profile: customerProfile);
    final repository = IdentityRepositoryImpl(client);
    passkeys = FakePasskeyPlatform();
    auth = AuthCubit(
      fetchMe: FetchMe(repository),
      tokens: MemoryTokenStore(),
      identityRepository: repository,
    );
    cubit = PhoneAuthCubit(
      createPhoneChallenge: CreatePhoneChallenge(repository),
      verifyPhoneChallenge: VerifyPhoneChallenge(repository),
      auth: auth,
      identityRepository: repository,
      passkeyPlatform: passkeys,
    );
  });

  tearDown(() async {
    await cubit.close();
    await auth.close();
  });

  test('createPhoneChallenge emits ready with challenge id', () async {
    final states = <PhoneAuthState>[];
    final sub = cubit.stream.listen(states.add);

    await cubit.createPhoneChallenge('+84987654321');
    await Future<void>.delayed(Duration.zero);
    await sub.cancel();

    expect(states, [
      isA<PhoneAuthSubmittingChallenge>(),
      isA<PhoneAuthChallengeReady>()
          .having((s) => s.phone, 'phone', '+84987654321')
          .having((s) => s.challengeId, 'challengeId', 'challenge-1'),
    ]);
    expect(client.challengedPhones, ['+84987654321']);
  });

  test('verifyOtp completes session via AuthCubit', () async {
    final states = <PhoneAuthState>[];
    final sub = cubit.stream.listen(states.add);

    await cubit.verifyOtp(
      challengeId: 'challenge-1',
      phone: '+84987654321',
      code: '123456',
    );
    await Future<void>.delayed(Duration.zero);
    await sub.cancel();

    expect(states, [isA<PhoneAuthVerifying>()]);
    expect(client.verifyCalls, [(challengeId: 'challenge-1', code: '123456')]);
    expect(auth.state, isA<AuthSignedIn>());
  });

  test('verifyOtp emits typed error on invalid code', () async {
    client.verifyError = const ApiException(
      statusCode: 401,
      errorCode: 'AUTH_CODE_INVALID',
      message: 'Verification code is invalid',
    );
    final states = <PhoneAuthState>[];
    final sub = cubit.stream.listen(states.add);

    await cubit.verifyOtp(
      challengeId: 'challenge-1',
      phone: '+84987654321',
      code: '000000',
    );
    await Future<void>.delayed(Duration.zero);
    await sub.cancel();

    expect(states, [
      isA<PhoneAuthVerifying>(),
      isA<PhoneAuthError>()
          .having((s) => s.phase, 'phase', PhoneAuthPhase.verify)
          .having((s) => s.error.errorCode, 'code', 'AUTH_CODE_INVALID'),
    ]);
  });

  test('resendChallenge replaces challenge id', () async {
    final states = <PhoneAuthState>[];
    final sub = cubit.stream.listen(states.add);

    await cubit.resendChallenge(
      phone: '+84987654321',
      previousChallengeId: 'challenge-old',
    );
    await Future<void>.delayed(Duration.zero);
    await sub.cancel();

    expect(states, [
      isA<PhoneAuthResending>(),
      isA<PhoneAuthChallengeReady>().having(
        (s) => s.challengeId,
        'challengeId',
        'challenge-1',
      ),
    ]);
  });

  test(
    'registerWithEmail emits an email challenge without signing in',
    () async {
      final states = <PhoneAuthState>[];
      final sub = cubit.stream.listen(states.add);

      await cubit.registerWithEmail(
        email: ' new@dealgo.vn ',
        password: 'password123',
      );
      await Future<void>.delayed(Duration.zero);
      await sub.cancel();

      expect(states, [
        isA<PhoneAuthEmailSigningIn>(),
        isA<PhoneAuthEmailChallengeReady>()
            .having((s) => s.email, 'email', 'new@dealgo.vn')
            .having((s) => s.challengeId, 'challengeId', 'email-challenge-1'),
      ]);
      expect(auth.state, isNot(isA<AuthSignedIn>()));
    },
  );

  test(
    'loginWithEmail moves an unverified account to the email OTP step',
    () async {
      client.seedUnverifiedEmailAccount('old@dealgo.vn', 'password123');
      final states = <PhoneAuthState>[];
      final sub = cubit.stream.listen(states.add);

      await cubit.loginWithEmail(
        email: ' old@dealgo.vn ',
        password: 'password123',
      );
      await Future<void>.delayed(Duration.zero);
      await sub.cancel();

      expect(states, [
        isA<PhoneAuthEmailSigningIn>(),
        isA<PhoneAuthEmailChallengeReady>()
            .having((s) => s.email, 'email', 'old@dealgo.vn')
            .having((s) => s.challengeId, 'challengeId', 'email-activation-1'),
      ]);
      expect(auth.state, isNot(isA<AuthSignedIn>()));

      await cubit.verifyEmailRegistration(
        challengeId: 'email-activation-1',
        email: 'old@dealgo.vn',
        code: '123456',
      );
      expect(auth.state, isA<AuthSignedIn>());
    },
  );

  test('loginWithEmail keeps AUTH_EMAIL_NOT_VERIFIED as an error without a challenge', () async {
    client.emailAuthError = const ApiException(
      statusCode: 403,
      errorCode: 'AUTH_EMAIL_NOT_VERIFIED',
      message: 'Email address is not verified',
    );
    final states = <PhoneAuthState>[];
    final sub = cubit.stream.listen(states.add);

    await cubit.loginWithEmail(email: 'old@dealgo.vn', password: 'password123');
    await Future<void>.delayed(Duration.zero);
    await sub.cancel();

    expect(
      states.last,
      isA<PhoneAuthError>().having(
        (s) => s.phase,
        'phase',
        PhoneAuthPhase.emailLogin,
      ),
    );
  });

  test('verifyEmailRegistration signs in after the emailed code', () async {
    final challenge = await client.registerWithEmail(
      email: 'new@dealgo.vn',
      password: 'password123',
    );

    await cubit.verifyEmailRegistration(
      challengeId: challenge.challengeId,
      email: 'new@dealgo.vn',
      code: '123456',
    );

    expect(client.verifyEmailCalls, [
      (challengeId: challenge.challengeId, code: '123456'),
    ]);
    expect(auth.state, isA<AuthSignedIn>());
  });

  test('verifyEmailRegistration keeps the challenge on a wrong code', () async {
    client.emailVerifyError = const ApiException(
      statusCode: 429,
      errorCode: 'AUTH_CODE_LOCKED',
      message: 'Verification code is locked',
    );
    final states = <PhoneAuthState>[];
    final sub = cubit.stream.listen(states.add);

    await cubit.verifyEmailRegistration(
      challengeId: 'email-challenge-9',
      email: 'new@dealgo.vn',
      code: '000000',
    );
    cubit.clearError();
    await Future<void>.delayed(Duration.zero);
    await sub.cancel();

    expect(states, [
      isA<PhoneAuthEmailVerifying>(),
      isA<PhoneAuthError>()
          .having((s) => s.phase, 'phase', PhoneAuthPhase.emailVerify)
          .having((s) => s.email, 'email', 'new@dealgo.vn'),
      isA<PhoneAuthEmailChallengeReady>().having(
        (s) => s.challengeId,
        'challengeId',
        'email-challenge-9',
      ),
    ]);
    expect(auth.state, isNot(isA<AuthSignedIn>()));
  });

  test('resendEmailRegistration reports server cooldown as an error', () async {
    client.emailResendError = const ApiException(
      statusCode: 429,
      errorCode: 'AUTH_OTP_RESEND_COOLDOWN',
      message: 'Wait before requesting another code',
    );
    final states = <PhoneAuthState>[];
    final sub = cubit.stream.listen(states.add);

    await cubit.resendEmailRegistration(
      email: 'new@dealgo.vn',
      challengeId: 'email-challenge-1',
    );
    await Future<void>.delayed(Duration.zero);
    await sub.cancel();

    expect(states, [
      isA<PhoneAuthEmailResending>(),
      isA<PhoneAuthError>()
          .having((s) => s.phase, 'phase', PhoneAuthPhase.emailResend)
          .having((s) => s.error.statusCode, 'status', 429),
    ]);
    expect(client.resendEmailCalls, ['email-challenge-1']);
  });

  test('enterMockDemo signs in through AuthCubit', () async {
    final states = <PhoneAuthState>[];
    final sub = cubit.stream.listen(states.add);

    await cubit.enterMockDemo();
    await Future<void>.delayed(Duration.zero);
    await sub.cancel();

    expect(states, [isA<PhoneAuthMockSigningIn>()]);
    expect(client.challengedPhones, ['+84900000000']);
    expect(client.verifyCalls, [(challengeId: 'challenge-1', code: '000000')]);
    expect(auth.state, isA<AuthSignedIn>());
  });

  test('passkey sign-in is identifierless and binds the ceremony', () async {
    await cubit.signInWithPasskey();

    expect(client.passkeyOptionCalls, [true]);
    expect(passkeys.authenticateCalls, hasLength(1));
    expect(passkeys.authenticateCalls.single, isNot(contains('ceremonyId')));
    expect(
      client.passkeyVerifyCalls.single['ceremonyId'],
      '00000000-0000-4000-8000-000000000001',
    );
    expect(auth.state, isA<AuthSignedIn>());
  });

  test('passkey sign-up creates a session without phone or email', () async {
    await cubit.signUpWithPasskey();

    expect(passkeys.registerCalls, hasLength(1));
    expect(passkeys.registerCalls.single, isNot(contains('ceremonyId')));
    expect(
      client.passkeySignupVerifyCalls.single['ceremonyId'],
      '00000000-0000-4000-8000-000000000002',
    );
    expect(auth.state, isA<AuthSignedIn>());
  });

  group('continue with passkey (one button)', () {
    test('existing passkey signs in and never creates an account', () async {
      await cubit.continueWithPasskey();

      expect(client.passkeyVerifyCalls, hasLength(1));
      expect(passkeys.registerCalls, isEmpty);
      expect(client.passkeySignupVerifyCalls, isEmpty);
      expect(auth.state, isA<AuthSignedIn>());
    });

    test('no passkey on the device -> creates account + passkey', () async {
      passkeys.authenticateFailure = PasskeyFailureKind.noCredentials;

      await cubit.continueWithPasskey();

      expect(passkeys.authenticateCalls, hasLength(1));
      expect(client.passkeyVerifyCalls, isEmpty);
      expect(passkeys.registerCalls, hasLength(1));
      // Fresh sign-up ceremony, never the sign-in one.
      expect(
        client.passkeySignupVerifyCalls.single['ceremonyId'],
        '00000000-0000-4000-8000-000000000002',
      );
      expect(auth.state, isA<AuthSignedIn>());
    });

    test(
      'server does not know the passkey -> falls through to sign-up',
      () async {
        client.verifyError = const ApiException(
          statusCode: 401,
          errorCode: 'AUTH_PASSKEY_INVALID',
          message: 'Passkey could not be verified',
        );

        await cubit.continueWithPasskey();

        expect(client.passkeyVerifyCalls, hasLength(1));
        expect(client.passkeySignupVerifyCalls, hasLength(1));
      },
    );

    test('cancel is quiet and creates nothing', () async {
      passkeys.authenticateFailure = PasskeyFailureKind.cancelled;

      await cubit.continueWithPasskey();

      expect(passkeys.registerCalls, isEmpty);
      expect(client.passkeySignupVerifyCalls, isEmpty);
      expect(cubit.state, isA<PhoneAuthIdle>());
      expect(auth.state, isNot(isA<AuthSignedIn>()));
    });

    test('other server errors surface and do not create an account', () async {
      client.verifyError = const ApiException(
        statusCode: 429,
        errorCode: 'RATE_LIMITED',
        message: 'Too many requests',
      );

      await cubit.continueWithPasskey();

      expect(client.passkeySignupVerifyCalls, isEmpty);
      expect(cubit.state, isA<PhoneAuthError>());
    });
  });
}
