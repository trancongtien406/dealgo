import 'package:flutter_test/flutter_test.dart';
import 'package:dealgo/features/identity/data/models/phone_challenge_model.dart';

void main() {
  test('email sign-up with verification on keeps the code step', () {
    final c = PhoneChallengeModel.fromJson({
      'challengeId': 'c1',
      'expiresAt': '2026-10-31T10:00:00Z',
    }).toEntity();
    expect(c.signedIn, isFalse);
  });

  test('verificationRequired false with a session signs in at once', () {
    final c = PhoneChallengeModel.fromJson({
      'challengeId': 'c1',
      'expiresAt': '2026-10-31T10:00:00Z',
      'verificationRequired': false,
      'session': {'accessToken': 'a', 'refreshToken': 'r', 'expiresIn': 900},
    }).toEntity();
    expect(c.signedIn, isTrue);
    expect(c.accessToken, 'a');
    expect(c.refreshToken, 'r');
  });
}
