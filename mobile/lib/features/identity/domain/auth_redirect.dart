import '../../../core/auth/post_auth_gate.dart';
import 'entities/app_role.dart';
import 'entities/auth_method_policy.dart';
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

/// Answers whether a sign-in method (an [AuthMethodPolicy] name) is switched on.
typedef AuthMethodAvailable = bool Function(String method);

/// [methodAvailable] keeps pages of switched-off sign-in methods unreachable,
/// deep links included: they land on the login picker instead. Without it
/// every method counts as on.
String? authRedirect(
  AuthState auth,
  Uri uri, {
  PostAuthGate? postAuth,
  bool? profileSetupCompleted,
  AuthMethodAvailable? methodAvailable,
}) {
  final path = uri.path;
  final method = _methodOf(uri);
  if (method != null &&
      auth is! AuthSignedIn &&
      !(methodAvailable?.call(method) ?? true)) {
    return AuthRoutes.login;
  }
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
      final next = _signedInRedirect(
        path,
        profile.activeAppRoles,
        profileDone: profileDone,
      );
      // The password belongs to email sign-in: hidden with it.
      if (next == null &&
          path.endsWith(_changePasswordSuffix) &&
          !(methodAvailable?.call(AuthMethodPolicy.email) ?? true)) {
        return '${path.substring(0, path.length - _changePasswordSuffix.length)}/security';
      }
      return next;
  }
}

const _changePasswordSuffix = '/change-password';

/// Sign-in method a signed-out page belongs to, or null for shared pages.
String? _methodOf(Uri uri) {
  switch (uri.path) {
    case AuthRoutes.phoneLogin:
      return AuthMethodPolicy.phoneSms;
    case AuthRoutes.emailLogin:
    case AuthRoutes.forgotPassword:
      return AuthMethodPolicy.email;
    case AuthRoutes.otp:
      final email = uri.queryParameters['email'];
      return email != null && email.isNotEmpty
          ? AuthMethodPolicy.email
          : AuthMethodPolicy.phoneSms;
  }
  return null;
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
