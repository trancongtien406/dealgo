import 'package:equatable/equatable.dart';

class CreatePhoneChallengeParams extends Equatable {
  const CreatePhoneChallengeParams(this.phone);

  final String phone;

  @override
  List<Object?> get props => [phone];
}
