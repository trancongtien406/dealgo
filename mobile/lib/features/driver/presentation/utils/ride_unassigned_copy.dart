import '../../../../l10n/app_localizations.dart';

/// Driver-facing reason for "the ride went to another driver"
/// (ASSIGNED/EN_ROUTE → NEGOTIATING). Codes come from the backend
/// `RideUnassignment.reasonCode`.
String rideUnassignedReason(AppLocalizations l10n, String reasonCode) {
  switch (reasonCode) {
    case 'ASSIGNED_TIMEOUT':
      return l10n.driverRideUnassignedStartTimeout;
    case 'EN_ROUTE_TIMEOUT':
      return l10n.driverRideUnassignedArriveTimeout;
    case 'OPS_REASSIGN':
      return l10n.driverRideUnassignedOps;
  }
  return l10n.driverRideUnassignedGeneric;
}

/// `Chuyến đã chuyển cho tài xế khác\n[lý do]`.
String rideUnassignedMessage(AppLocalizations l10n, String reasonCode) =>
    '${l10n.driverRideUnassignedTitle}\n${rideUnassignedReason(l10n, reasonCode)}';
