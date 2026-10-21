import '../../../../core/network/api_exception.dart';
import '../../domain/entities/verified_session.dart';

class VerifiedSessionModel {
  const VerifiedSessionModel({
    required this.accessToken,
    required this.refreshToken,
    required this.expiresIn,
  });

  final String accessToken;
  final String refreshToken;
  final int expiresIn;

  factory VerifiedSessionModel.fromJson(Map<String, Object?> json) {
    final accessToken = json['accessToken'];
    final refreshToken = json['refreshToken'];
    final expiresIn = json['expiresIn'];
    final seconds = expiresIn is int
        ? expiresIn
        : expiresIn is num
        ? expiresIn.toInt()
        : null;
    if (accessToken is! String ||
        accessToken.isEmpty ||
        refreshToken is! String ||
        refreshToken.isEmpty ||
        seconds == null ||
        seconds < 0) {
      throw const ApiException(
        statusCode: 200,
        message: 'Invalid response',
        errorCode: 'INVALID_RESPONSE',
      );
    }
    return VerifiedSessionModel(
      accessToken: accessToken,
      refreshToken: refreshToken,
      expiresIn: seconds,
    );
  }

  Map<String, Object?> toJson() {
    return {
      'accessToken': accessToken,
      'refreshToken': refreshToken,
      'expiresIn': expiresIn,
    };
  }

  VerifiedSession toEntity() {
    return VerifiedSession(
      accessToken: accessToken,
      refreshToken: refreshToken,
      expiresIn: expiresIn,
    );
  }
}
