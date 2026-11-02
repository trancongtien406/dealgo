import '../../../../core/l10n/api_error_text.dart';
import '../../../../core/network/api_exception.dart';
import '../../../../l10n/app_localizations.dart';

/// t71u: quote errors that retrying cannot fix (route outside / across
/// service regions) get a friendly message instead of "check connection".
const _kZoneCodes = {
  'RIDE_CROSS_REGION_NOT_SUPPORTED',
  'RIDE_OUTSIDE_SERVICE_ZONE',
};

String? rideQuoteZoneErrorText(AppLocalizations l10n, Object? error) {
  if (error is ApiException && _kZoneCodes.contains(error.errorCode)) {
    return apiErrorText(l10n, error);
  }
  return null;
}
