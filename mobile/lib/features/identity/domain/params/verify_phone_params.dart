import 'package:equatable/equatable.dart';

class VerifyPhoneParams extends Equatable {
  const VerifyPhoneParams({required this.challengeId, required this.code});

  final String challengeId;
  final String code;

  @override
  List<Object?> get props => [challengeId, code];
}
