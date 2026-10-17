import 'package:equatable/equatable.dart';

class VerifiedSession extends Equatable {
  const VerifiedSession({
    required this.accessToken,
    required this.refreshToken,
    required this.expiresIn,
  });

  final String accessToken;
  final String refreshToken;
  final int expiresIn;

  @override
  List<Object?> get props => [accessToken, refreshToken, expiresIn];

  @override
  String toString() => 'VerifiedSession(expiresIn: $expiresIn)';
}
