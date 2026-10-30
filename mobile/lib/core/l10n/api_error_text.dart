import '../../l10n/app_localizations.dart';
import '../network/api_exception.dart';
import '../observability/crash_reporting.dart';

/// User-facing text for a failed call. Server `message` fields are English developer text,
/// so they are never shown: known codes get their own sentence, the rest fall back by status.
///
/// Failures that are bugs rather than answers (non-API errors, malformed
/// responses) go to crash reporting with their details; the user only sees the
/// friendly sentence. Sentry drops repeats of the same error object, so
/// resolving one message on every rebuild reports it once. 5xx answers are
/// reported where they happen (`DioErrorReporter`).
String apiErrorText(
  AppLocalizations l10n,
  Object? error, {
  String? fallback,
  bool report = true,
}) {
  if (error is! ApiException) {
    if (report && error != null) reportHandledError(error);
    return fallback ?? l10n.apiErrGeneric;
  }
  if (report && _malformed.contains(error.errorCode)) {
    reportHandledError(error);
  }
  final byCode = _byCode(l10n, error.errorCode);
  if (byCode != null) {
    return byCode;
  }
  return switch (error.statusCode) {
    0 => l10n.apiErrNetwork,
    401 => l10n.errorSessionExpired,
    403 => l10n.apiErrForbidden,
    404 => l10n.apiErrNotFound,
    409 || 423 => l10n.apiErrConflict,
    410 => l10n.apiErrGone,
    413 => l10n.apiErrTooLarge,
    415 => l10n.apiErrBadType,
    429 => l10n.apiErrTooMany,
    >= 500 => l10n.apiErrServer,
    _ => fallback ?? l10n.apiErrGeneric,
  };
}

const _malformed = {'INVALID_RESPONSE', 'MALFORMED_RESPONSE'};

String? _byCode(AppLocalizations l10n, String code) => switch (code) {
  'NETWORK_ERROR' => l10n.apiErrNetwork,
  'INVALID_RESPONSE' || 'MALFORMED_RESPONSE' => l10n.apiErrInvalidResponse,
  'AUTH_PASSKEY_INVALID' => l10n.apiErrPasskeyInvalid,
  'PASSKEY_UNAVAILABLE' ||
  'WEBAUTHN_NOT_CONFIGURED' => l10n.apiErrPasskeyUnavailable,
  'AUTH_PASSKEY_EXISTS' => l10n.securityPasskeyExists,
  'UNAUTHORIZED' ||
  'AUTH_REFRESH_INVALID' ||
  'AUTH_REFRESH_REUSED' => l10n.errorSessionExpired,
  'ACCOUNT_DELETED' => l10n.apiErrAccountDeleted,
  'ROLE_NOT_ACTIVE' => l10n.apiErrRoleNotActive,
  'ROLE_GRANT_SUSPENDED' => l10n.apiErrRoleSuspended,
  'VALIDATION_ERROR' => l10n.apiErrValidation,
  'RIDE_ROUTE_CHANGED' => l10n.rideRouteChanged,
  'RIDE_STOPS_LOCKED' => l10n.rideStopsLocked,
  'RIDE_STOPS_DISABLED' || 'RIDE_TOO_MANY_STOPS' => l10n.rideStopsUnavailable,
  'RIDE_STOPS_PENDING' => l10n.driverStopsPendingError,
  'UPLOAD_TOO_LARGE' => l10n.apiErrTooLarge,
  'UPLOAD_TYPE_NOT_ALLOWED' ||
  'UPLOAD_TYPE_MISMATCH' ||
  'UPLOAD_INVALID' => l10n.apiErrBadType,
  'STORAGE_UNAVAILABLE' || 'EMAIL_DELIVERY_FAILED' => l10n.apiErrServer,
  'VOICE_DISABLED' => l10n.apiErrVoiceDisabled,
  'VOICE_UNAVAILABLE' => l10n.apiErrVoiceUnavailable,
  'VOICE_BUSY' => l10n.apiErrVoiceBusy,
  'VOICE_NO_COUNTERPART' => l10n.apiErrVoiceNoCounterpart,
  'VOICE_WINDOW_CLOSED' => l10n.apiErrVoiceWindowClosed,
  'VOICE_CALL_NOT_RINGING' => l10n.voiceEndedMissed,
  'RIDE_NOT_FOUND' => l10n.apiErrRideNotFound,
  'RIDE_STATUS_CONFLICT' => l10n.apiErrRideChanged,
  'RIDE_NOT_CANCELLABLE' => l10n.apiErrRideNotCancellable,
  'RIDE_FARE_OUT_OF_RANGE' ||
  'RIDE_COUNTER_OUT_OF_RANGE' => l10n.apiErrFareOutOfRange,
  'RIDE_ALREADY_OPEN' => l10n.apiErrRideAlreadyOpen,
  'RIDE_OFFER_EXPIRED' => l10n.rideOfferExpiredShort,
  'RIDE_OFFER_UNAVAILABLE' ||
  'RIDE_OFFER_NOT_FOUND' => l10n.rideOfferUnavailable,
  'RIDE_NEGOTIATION_ROUNDS_EXCEEDED' => l10n.apiErrNegotiationLimit,
  'RIDE_SELF_OFFER' || 'FOOD_SELF_CLAIM' => l10n.apiErrSelfAction,
  'RIDE_NOT_ASSIGNED_DRIVER' ||
  'FOOD_NOT_ASSIGNED_DRIVER' => l10n.apiErrNotYourJob,
  'FOOD_ORDER_NOT_FOUND' => l10n.apiErrOrderNotFound,
  'FOOD_STATUS_CONFLICT' => l10n.apiErrOrderChanged,
  'FOOD_ALREADY_ASSIGNED' => l10n.apiErrJobTaken,
  'FOOD_NOT_CANCELLABLE' => l10n.apiErrOrderNotCancellable,
  'FOOD_NOT_STORE_OWNER' => l10n.apiErrNotStoreOwner,
  'FOOD_ITEM_NOT_FOUND' => l10n.apiErrItemNotFound,
  'FOOD_ITEM_UNAVAILABLE' => l10n.checkoutErrItemUnavailable,
  'FOOD_OPTION_INVALID' => l10n.apiErrFoodOptionInvalid,
  'FOOD_OPTIONS_INVALID' => l10n.merchantOptionsInvalidGroup,
  'FOOD_STORE_NOT_FOUND' => l10n.checkoutErrStoreNotFound,
  'FOOD_STORE_PAUSED' => l10n.checkoutErrStorePaused,
  'FOOD_STORE_CLOSED' => l10n.checkoutErrStoreClosed,
  'FOOD_MIN_ORDER_NOT_MET' => l10n.checkoutErrMinOrder,
  'FOOD_STORE_AT_CAPACITY' => l10n.checkoutErrStoreAtCapacity,
  'FOOD_HOURS_INVALID' => l10n.merchantHoursErrInvalid,
  'FOOD_ORDER_ALREADY_OPEN' => l10n.checkoutErrOrderOpen,
  'RIDE_LIVE_OFFERS_FULL' => l10n.apiErrLiveOffersFull,
  'RIDE_FARE_RAISE_LIMIT' => l10n.apiErrFareRaiseLimit,
  'RIDE_CANCEL_COOLDOWN' => l10n.apiErrCancelCooldown,
  'RIDE_REPOST_INVALID' => l10n.apiErrRepostInvalid,
  'FOOD_FAIL_TOO_EARLY' => l10n.apiErrFailTooEarly,
  'FOOD_FAIL_NOTE_REQUIRED' => l10n.apiErrFailNoteRequired,
  'FOOD_STORE_LOCATION_REQUIRED' => l10n.apiErrStoreLocationRequired,
  'DRIVER_LOCATION_STALE' => l10n.apiErrDriverLocationStale,
  'FOOD_OUTSIDE_SERVICE_ZONE' => l10n.apiErrOutsideServiceZone,
  'FOOD_TOO_FAR' => l10n.apiErrTooFar,
  'FOOD_SETTLEMENT_OVERLAP' => l10n.apiErrSettlementOverlap,
  'FOOD_SETTLEMENT_PERIOD_OPEN' => l10n.apiErrSettlementPeriodOpen,
  'PARTNER_SHOP_LOCATION_REQUIRED' => l10n.apiErrShopLocationRequired,
  'FOOD_CHANGE_PENDING' => l10n.apiErrChangePending,
  'FOOD_CHANGE_INVALID' => l10n.apiErrChangeInvalid,
  'FOOD_CHANGE_NOT_FOUND' => l10n.apiErrChangeNotFound,
  'VOUCHER_NOT_FOUND' => l10n.apiErrVoucherNotFound,
  'VOUCHER_EXPIRED' ||
  'VOUCHER_INACTIVE' ||
  'VOUCHER_PAUSED' => l10n.apiErrVoucherEnded,
  'VOUCHER_NOT_STARTED' => l10n.apiErrVoucherNotStarted,
  'VOUCHER_MIN_ORDER' => l10n.apiErrVoucherMinOrder,
  'VOUCHER_BUDGET_EXHAUSTED' ||
  'VOUCHER_USAGE_EXHAUSTED' => l10n.apiErrVoucherUsedUp,
  'VOUCHER_USER_LIMIT' => l10n.apiErrVoucherUserLimit,
  'VOUCHER_WRONG_SERVICE' => l10n.apiErrVoucherWrongService,
  _ => null,
};
