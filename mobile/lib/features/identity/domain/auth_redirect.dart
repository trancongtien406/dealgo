import '../../../core/auth/post_auth_gate.dart';
import 'entities/app_role.dart';
import 'entities/auth_state.dart';

abstract final class AuthRoutes {
  static const splash = '/splash';
  static const login = '/login';
  static const phoneLogin = '/login/phone';
  static const emailLogin = '/login/email';
  static const forgotPassword = '/login/email/forgot';
  static const otp = '/login/otp';
  static const roles = '/roles';
  static const onboarding = '/onboarding';
  static const profileSetup = '/onboarding/profile';
  static const permissions = '/onboarding/permissions';
}

String? authRedirect(
  AuthState auth,
  Uri uri, {
  PostAuthGate? postAuth,
  bool? profileSetupCompleted,
}) {
  final path = uri.path;
  switch (auth) {
    case AuthRestoring():
      if (path == AuthRoutes.splash ||
          path == AuthRoutes.onboarding ||
          path == AuthRoutes.roles ||
          path == AuthRoutes.login ||
          path == AuthRoutes.phoneLogin ||
          path == AuthRoutes.emailLogin ||
          path == AuthRoutes.forgotPassword ||
          path == AuthRoutes.profileSetup) {
        return null;
      }
      if (path == AuthRoutes.otp && _hasOtpQuery(uri)) {
        return null;
      }
      return AuthRoutes.login;
    case AuthSignedOut():
      return _signedOutRedirect(path, uri);
    case AuthSignedIn(:final profile):
      final profileDone =
          profileSetupCompleted ?? postAuth?.profileSetupCompleted ?? false;
      return _signedInRedirect(
        path,
        profile.activeAppRoles,
        profileDone: profileDone,
      );
  }
}

String? _signedOutRedirect(String path, Uri uri) {
  if (path == AuthRoutes.splash || path == AuthRoutes.onboarding) {
    return null;
  }
  if (path == AuthRoutes.otp) {
    return _hasOtpQuery(uri) ? null : AuthRoutes.login;
  }
  if (path == AuthRoutes.login ||
      path == AuthRoutes.phoneLogin ||
      path == AuthRoutes.emailLogin ||
      path == AuthRoutes.forgotPassword) {
    return null;
  }
  return AuthRoutes.login;
}

String? _signedInRedirect(
  String path,
  List<AppRole> roles, {
  required bool profileDone,
}) {
  final entry = entryPathFor(roles);

  // Legacy deep link: permissions page removed; send users onward.
  if (path == AuthRoutes.permissions) {
    return profileDone ? entry : AuthRoutes.profileSetup;
  }

  if (path == AuthRoutes.profileSetup || path == AuthRoutes.roles) {
    return null;
  }

  if (_isAuthEntryPath(path)) {
    if (!profileDone) {
      return AuthRoutes.profileSetup;
    }
    return entry;
  }

  if (!profileDone) {
    return AuthRoutes.profileSetup;
  }

  if (shellAllows(path, roles)) {
    return null;
  }
  return entry;
}

bool _isAuthEntryPath(String path) {
  return path == AuthRoutes.splash ||
      path == AuthRoutes.login ||
      path == AuthRoutes.phoneLogin ||
      path == AuthRoutes.emailLogin ||
      path == AuthRoutes.otp ||
      path == AuthRoutes.onboarding;
}

/// OTP route needs a challenge and exactly one destination: `phone` or `email` (sign-up).
bool _hasOtpQuery(Uri uri) {
  final challengeId = uri.queryParameters['challengeId'];
  final phone = uri.queryParameters['phone'];
  final email = uri.queryParameters['email'];
  final hasPhone = phone != null && phone.isNotEmpty;
  final hasEmail = email != null && email.isNotEmpty;
  return challengeId != null && challengeId.isNotEmpty && hasPhone != hasEmail;
}
