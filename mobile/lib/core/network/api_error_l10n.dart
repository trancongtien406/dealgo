import 'package:flutter/widgets.dart';

import '../../l10n/app_localizations.dart';
import 'api_exception.dart';

extension ApiExceptionL10n on ApiException {
  String localizedMessage(AppLocalizations l10n) {
    return switch (errorCode) {
      'NETWORK_ERROR' => l10n.errorNetwork,
      'UNAUTHORIZED' || 'SESSION_EXPIRED' => l10n.errorSessionExpired,
      'HTTP_ERROR' when statusCode == 401 => l10n.errorUnauthorized,
      _ when message.trim().isNotEmpty => message,
      _ => l10n.errorGeneric,
    };
  }
}

String localizedFailureMessage(BuildContext context, Object error) {
  final l10n = AppLocalizations.of(context);
  if (error is ApiException) {
    return error.localizedMessage(l10n);
  }
  return l10n.errorNetwork;
}

String sessionExpiredMessage(BuildContext context) {
  return AppLocalizations.of(context).errorSessionExpired;
}

String networkErrorMessage(BuildContext context) {
  return AppLocalizations.of(context).errorNetwork;
}
