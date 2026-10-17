import 'package:dealgo/core/network/api_exception.dart';
import 'package:dealgo/features/identity/data/repositories/identity_repository_impl.dart';
import 'package:dealgo/features/identity/domain/entities/auth_state.dart';
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

  setUp(() {
    client = FakeIdentityClient(profile: customerProfile);
    final repository = IdentityRepositoryImpl(client);
    auth = AuthCubit(fetchMe: FetchMe(repository), tokens: MemoryTokenStore());
    cubit = PhoneAuthCubit(
      createPhoneChallenge: CreatePhoneChallenge(repository),
      verifyPhoneChallenge: VerifyPhoneChallenge(repository),
      auth: auth,
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
    expect(client.verifyCalls, [
      (challengeId: 'challenge-1', code: '123456'),
    ]);
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

  test('enterMockDemo signs in through AuthCubit', () async {
    final states = <PhoneAuthState>[];
    final sub = cubit.stream.listen(states.add);

    await cubit.enterMockDemo();
    await Future<void>.delayed(Duration.zero);
    await sub.cancel();

    expect(states, [isA<PhoneAuthMockSigningIn>()]);
    expect(client.challengedPhones, ['+84900000000']);
    expect(client.verifyCalls, [
      (challengeId: 'challenge-1', code: '000000'),
    ]);
    expect(auth.state, isA<AuthSignedIn>());
  });
}
