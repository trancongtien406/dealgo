import 'package:equatable/equatable.dart';

/// A 6-digit code mailed to [email]; the address is set on the account only
/// once the code is confirmed.
class EmailVerification extends Equatable {
  const EmailVerification({
    required this.verificationId,
    required this.email,
    required this.expiresAt,
    required this.resendAvailableAt,
  });

  final String verificationId;
  final String email;
  final DateTime expiresAt;
  final DateTime resendAvailableAt;

  @override
  List<Object?> get props => [
    verificationId,
    email,
    expiresAt,
    resendAvailableAt,
  ];
}
