import 'package:equatable/equatable.dart';

class PhoneChallenge extends Equatable {
  const PhoneChallenge({
    required this.challengeId,
    required this.expiresAt,
    this.accessToken,
    this.refreshToken,
  });

  final String challengeId;
  final String expiresAt;

  /// Set when the server signed the user in at once (email sign-up with
  /// AUTH_EMAIL_VERIFICATION_REQUIRED off): no code step is needed.
  final String? accessToken;
  final String? refreshToken;

  bool get signedIn => accessToken != null && refreshToken != null;

  @override
  List<Object?> get props => [
    challengeId,
    expiresAt,
    accessToken,
    refreshToken,
  ];
}
