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

/// t90u: a car driver blocked only because the car documents (VEHICLE_INSURANCE)
/// are missing — the app offers "Bổ sung giấy tờ" instead of a generic 403.
bool isCarDocsRequired(Object? error) {
  if (error is! ApiException || error.statusCode != 403) return false;
  if (error.errorCode == 'PARTNER_CAR_DOCS_REQUIRED') return true;
  if (error.errorCode != 'PARTNER_KYC_REQUIRED') return false;
  return error.details?['reason'] == 'CAR_DOCS_REQUIRED' ||
      error.message.contains('VEHICLE_INSURANCE');
}
