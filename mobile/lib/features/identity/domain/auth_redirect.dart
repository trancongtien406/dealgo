import 'entities/app_role.dart';
import 'entities/auth_state.dart';

abstract final class AuthRoutes {
  static const login = '/login';
  static const otp = '/login/otp';
  static const roles = '/roles';
  static const onboarding = '/onboarding';
}

String? authRedirect(AuthState auth, Uri uri) {
  final path = uri.path;
  switch (auth) {
    case AuthRestoring():
      if (path == AuthRoutes.onboarding) {
        return null;
      }
      return path == AuthRoutes.login ? null : AuthRoutes.login;
    case AuthSignedOut():
      return _signedOutRedirect(path, uri);
    case AuthSignedIn(:final profile):
      return _signedInRedirect(path, profile.activeAppRoles);
  }
}

String? _signedOutRedirect(String path, Uri uri) {
  if (path == AuthRoutes.onboarding) {
    return null;
  }
  if (path == AuthRoutes.otp) {
    return _hasOtpQuery(uri) ? null : AuthRoutes.login;
  }
  if (path == AuthRoutes.login) {
    return null;
  }
  return AuthRoutes.login;
}

String? _signedInRedirect(String path, List<AppRole> roles) {
  final entry = entryPathFor(roles);
  if (path == AuthRoutes.login || path == AuthRoutes.otp || path == AuthRoutes.onboarding) {
    return entry;
  }
  if (path == AuthRoutes.roles) {
    return roles.length > 1 ? null : entry;
  }
  if (shellAllows(path, roles)) {
    return null;
  }
  return entry;
}

bool _hasOtpQuery(Uri uri) {
  final challengeId = uri.queryParameters['challengeId'];
  final phone = uri.queryParameters['phone'];
  return challengeId != null &&
      challengeId.isNotEmpty &&
      phone != null &&
      phone.isNotEmpty;
}
