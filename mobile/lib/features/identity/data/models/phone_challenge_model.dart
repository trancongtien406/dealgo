import '../../../../core/network/api_exception.dart';
import '../../domain/entities/phone_challenge.dart';
import 'verified_session_model.dart';

class PhoneChallengeModel {
  const PhoneChallengeModel({
    required this.challengeId,
    required this.expiresAt,
    this.session,
  });

  final String challengeId;
  final String expiresAt;

  /// Email sign-up without verification returns `verificationRequired: false`
  /// and the session alongside the challenge fields.
  final VerifiedSessionModel? session;

  factory PhoneChallengeModel.fromJson(Map<String, Object?> json) {
    final challengeId = json['challengeId'];
    final expiresAt = json['expiresAt'];
    if (challengeId is! String ||
        challengeId.isEmpty ||
        expiresAt is! String ||
        expiresAt.isEmpty) {
      throw const ApiException(
        statusCode: 200,
        message: 'Invalid response',
        errorCode: 'INVALID_RESPONSE',
      );
    }
    final session = json['session'];
    return PhoneChallengeModel(
      challengeId: challengeId,
      expiresAt: expiresAt,
      session: json['verificationRequired'] == false && session is Map
          ? VerifiedSessionModel.fromJson(Map<String, Object?>.from(session))
          : null,
    );
  }

  Map<String, Object?> toJson() {
    return {'challengeId': challengeId, 'expiresAt': expiresAt};
  }

  PhoneChallenge toEntity() {
    return PhoneChallenge(
      challengeId: challengeId,
      expiresAt: expiresAt,
      accessToken: session?.accessToken,
      refreshToken: session?.refreshToken,
    );
  }
}
