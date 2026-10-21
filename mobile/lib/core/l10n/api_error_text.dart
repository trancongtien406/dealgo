import '../../l10n/app_localizations.dart';
import '../network/api_exception.dart';

/// User-facing text for a failed call. Server `message` fields are English developer text,
/// so they are never shown: known codes get their own sentence, the rest fall back by status.
String apiErrorText(AppLocalizations l10n, Object? error, {String? fallback}) {
  if (error is! ApiException) {
    return fallback ?? l10n.apiErrGeneric;
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

String? _byCode(AppLocalizations l10n, String code) => switch (code) {
  'NETWORK_ERROR' => l10n.apiErrNetwork,
  'INVALID_RESPONSE' || 'MALFORMED_RESPONSE' => l10n.apiErrInvalidResponse,
  'UNAUTHORIZED' || 'AUTH_REFRESH_INVALID' || 'AUTH_REFRESH_REUSED' => l10n.errorSessionExpired,
  'ACCOUNT_DELETED' => l10n.apiErrAccountDeleted,
  'ROLE_NOT_ACTIVE' => l10n.apiErrRoleNotActive,
  'ROLE_GRANT_SUSPENDED' => l10n.apiErrRoleSuspended,
  'VALIDATION_ERROR' => l10n.apiErrValidation,
  'UPLOAD_TOO_LARGE' => l10n.apiErrTooLarge,
  'UPLOAD_TYPE_NOT_ALLOWED' || 'UPLOAD_TYPE_MISMATCH' || 'UPLOAD_INVALID' => l10n.apiErrBadType,
  'STORAGE_UNAVAILABLE' || 'EMAIL_DELIVERY_FAILED' => l10n.apiErrServer,
  'RIDE_NOT_FOUND' => l10n.apiErrRideNotFound,
  'RIDE_STATUS_CONFLICT' => l10n.apiErrRideChanged,
  'RIDE_NOT_CANCELLABLE' => l10n.apiErrRideNotCancellable,
  'RIDE_FARE_OUT_OF_RANGE' => l10n.apiErrFareOutOfRange,
  'RIDE_ALREADY_OPEN' => l10n.apiErrRideAlreadyOpen,
  'RIDE_OFFER_EXPIRED' => l10n.rideOfferExpiredShort,
  'RIDE_OFFER_UNAVAILABLE' || 'RIDE_OFFER_NOT_FOUND' => l10n.rideOfferUnavailable,
  'RIDE_NEGOTIATION_ROUNDS_EXCEEDED' => l10n.apiErrNegotiationLimit,
  'RIDE_SELF_OFFER' || 'FOOD_SELF_CLAIM' => l10n.apiErrSelfAction,
  'RIDE_NOT_ASSIGNED_DRIVER' || 'FOOD_NOT_ASSIGNED_DRIVER' => l10n.apiErrNotYourJob,
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
  'FOOD_STORE_AT_CAPACITY' => l10n.checkoutErrStoreAtCapacity,
  'FOOD_HOURS_INVALID' => l10n.merchantHoursErrInvalid,
  'FOOD_ORDER_ALREADY_OPEN' => l10n.checkoutErrOrderOpen,
  'VOUCHER_NOT_FOUND' => l10n.apiErrVoucherNotFound,
  'VOUCHER_EXPIRED' || 'VOUCHER_INACTIVE' || 'VOUCHER_PAUSED' => l10n.apiErrVoucherEnded,
  'VOUCHER_NOT_STARTED' => l10n.apiErrVoucherNotStarted,
  'VOUCHER_MIN_ORDER' => l10n.apiErrVoucherMinOrder,
  'VOUCHER_BUDGET_EXHAUSTED' || 'VOUCHER_USAGE_EXHAUSTED' => l10n.apiErrVoucherUsedUp,
  'VOUCHER_USER_LIMIT' => l10n.apiErrVoucherUserLimit,
  'VOUCHER_WRONG_SERVICE' => l10n.apiErrVoucherWrongService,
  _ => null,
};
