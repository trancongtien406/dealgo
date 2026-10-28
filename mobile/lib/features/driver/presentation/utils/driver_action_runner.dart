import 'package:flutter/widgets.dart';

import '../../../../core/design_system/components/dealgo_haptics.dart';
import '../../../../core/network/api_exception.dart';
import '../../../../l10n/app_localizations.dart';
import '../widgets/driver_widgets.dart';

/// Shared busy/error handling for driver state-machine buttons.
///
/// Keeps one request in flight, maps failures to localized copy and fires
/// success / error haptics.
mixin DriverActionRunner<T extends StatefulWidget> on State<T> {
  bool actionBusy = false;
  String? actionError;

  Future<bool> runDriverAction(
    Future<void> Function(String token) action,
  ) async {
    if (actionBusy) {
      return false;
    }
    final l10n = AppLocalizations.of(context);
    final token = driverAccessToken(context);
    if (token == null || token.isEmpty) {
      setState(() => actionError = l10n.errorSessionExpired);
      return false;
    }
    setState(() {
      actionBusy = true;
      actionError = null;
    });
    String? failure;
    try {
      await action(token);
    } on ApiException catch (error) {
      failure = switch (error.errorCode) {
        'RIDE_PICKUP_CODE_INVALID' => l10n.driverOtpWrong,
        'RIDE_PICKUP_CODE_LOCKED' => l10n.driverOtpLocked,
        'FOOD_DELIVERY_CODE_LOCKED' ||
        'FOOD_HANDOVER_CODE_LOCKED' => l10n.driverFoodCodeLocked,
        'RIDE_STOPS_PENDING' => l10n.driverStopsPendingError,
        'RIDE_ROUTE_CHANGED' => l10n.rideRouteChanged,
        _ => switch (error.statusCode) {
          401 => l10n.errorSessionExpired,
          409 => l10n.driverActionConflict,
          _ when error.statusCode <= 0 => l10n.errorNetwork,
          _ => l10n.driverActionFailed,
        },
      };
    } catch (_) {
      failure = l10n.driverActionFailed;
    }
    if (!mounted) {
      return false;
    }
    setState(() {
      actionBusy = false;
      actionError = failure;
    });
    if (failure == null) {
      DealGoHaptics.success();
    } else {
      DealGoHaptics.error();
    }
    return failure == null;
  }
}
