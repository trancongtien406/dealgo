import '../../../../core/auth/token_store.dart';
import 'user_profile.dart';

sealed class AuthState {
  const AuthState();
}

final class AuthRestoring extends AuthState {
  const AuthRestoring();
}

final class AuthSignedOut extends AuthState {
  const AuthSignedOut();
}

final class AuthSignedIn extends AuthState {
  const AuthSignedIn({required this.tokens, required this.profile});

  final StoredTokens tokens;
  final UserProfile profile;

  @override
  String toString() => 'AuthSignedIn(${profile.id})';
}
