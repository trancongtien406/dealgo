import 'package:flutter/widgets.dart';

import '../../l10n/app_localizations.dart';
import '../l10n/api_error_text.dart';
import 'api_exception.dart';

extension ApiExceptionL10n on ApiException {
  String localizedMessage(AppLocalizations l10n) {
    return apiErrorText(l10n, this);
  }
}

String localizedFailureMessage(BuildContext context, Object error) {
  final l10n = AppLocalizations.of(context);
  return apiErrorText(l10n, error);
}

String sessionExpiredMessage(BuildContext context) {
  return AppLocalizations.of(context).errorSessionExpired;
}

String networkErrorMessage(BuildContext context) {
  return AppLocalizations.of(context).errorNetwork;
}
