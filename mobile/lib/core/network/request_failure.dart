import 'api_exception.dart';

/// Why a list or detail request failed, for the matching full-screen state.
enum RequestFailureKind { offline, permission, error }

RequestFailureKind requestFailureKind(Object? error) {
  if (error is! ApiException) {
    return RequestFailureKind.error;
  }
  if (error.statusCode == 0 || error.errorCode == 'NETWORK_ERROR') {
    return RequestFailureKind.offline;
  }
  if (error.statusCode == 401 ||
      error.statusCode == 403 ||
      error.errorCode == 'UNAUTHORIZED' ||
      error.errorCode == 'ROLE_NOT_ACTIVE' ||
      error.errorCode == 'ROLE_GRANT_SUSPENDED') {
    return RequestFailureKind.permission;
  }
  return RequestFailureKind.error;
}

bool requestFailureIsOffline(Object? error) =>
    requestFailureKind(error) == RequestFailureKind.offline;

/// Local session is gone, so the screen cannot load.
const sessionExpiredFailure = ApiException(
  statusCode: 401,
  message: '',
  errorCode: 'UNAUTHORIZED',
);
