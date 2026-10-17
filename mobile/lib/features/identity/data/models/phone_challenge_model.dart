import '../../../../core/network/api_exception.dart';
import '../../domain/entities/phone_challenge.dart';

class PhoneChallengeModel {
  const PhoneChallengeModel({
    required this.challengeId,
    required this.expiresAt,
  });

  final String challengeId;
  final String expiresAt;

  factory PhoneChallengeModel.fromJson(Map<String, Object?> json) {
    final challengeId = json['challengeId'];
    final expiresAt = json['expiresAt'];
    if (challengeId is! String ||
        challengeId.isEmpty ||
        expiresAt is! String ||
        expiresAt.isEmpty) {
      throw const ApiException(
        statusCode: 200,
        message: 'Phản hồi không hợp lệ',
        errorCode: 'INVALID_RESPONSE',
      );
    }
    return PhoneChallengeModel(
      challengeId: challengeId,
      expiresAt: expiresAt,
    );
  }

  Map<String, Object?> toJson() {
    return {'challengeId': challengeId, 'expiresAt': expiresAt};
  }

  PhoneChallenge toEntity() {
    return PhoneChallenge(challengeId: challengeId, expiresAt: expiresAt);
  }
}
