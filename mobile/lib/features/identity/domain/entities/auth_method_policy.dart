class AuthMethodPolicy {
  const AuthMethodPolicy({required this.method, required this.enabled});

  final String method;
  final bool enabled;

  static const passkey = 'PASSKEY';
  static const phoneSms = 'PHONE_SMS';
  static const email = 'EMAIL_LOGIN_IDENTIFIER';

  bool get isPasskey => method == passkey;
  bool get isPhoneSms => method == phoneSms;
  bool get isEmail => method == email;
}
