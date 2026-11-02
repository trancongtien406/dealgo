import '../../../../core/network/api_exception.dart';
import '../../domain/entities/email_verification.dart';

class EmailVerificationModel {
  const EmailVerificationModel({
    required this.verificationId,
    required this.expiresAt,
    required this.resendAvailableAt,
  });

  final String verificationId;
  final DateTime expiresAt;
  final DateTime resendAvailableAt;

  factory EmailVerificationModel.fromJson(Map<String, Object?> json) {
    final id = json['verificationId'];
    final expiresAt = DateTime.tryParse('${json['expiresAt']}');
    if (id is! String || id.isEmpty || expiresAt == null) {
      throw const ApiException(
        statusCode: 200,
        message: 'Invalid response',
        errorCode: 'INVALID_RESPONSE',
      );
    }
    return EmailVerificationModel(
      verificationId: id,
      expiresAt: expiresAt,
      resendAvailableAt:
          DateTime.tryParse('${json['resendAvailableAt']}') ?? DateTime.now(),
    );
  }

  EmailVerification toEntity(String email) => EmailVerification(
    verificationId: verificationId,
    email: email,
    expiresAt: expiresAt,
    resendAvailableAt: resendAvailableAt,
  );
}
