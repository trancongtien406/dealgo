import 'package:equatable/equatable.dart';

class PhoneChallenge extends Equatable {
  const PhoneChallenge({required this.challengeId, required this.expiresAt});

  final String challengeId;
  final String expiresAt;

  @override
  List<Object?> get props => [challengeId, expiresAt];
}
