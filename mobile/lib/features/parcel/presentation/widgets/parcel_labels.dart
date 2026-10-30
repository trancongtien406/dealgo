import '../../../../l10n/app_localizations.dart';
import '../../domain/parcel_models.dart';

String parcelSizeLabel(AppLocalizations l10n, String code) => switch (code) {
  'S' => l10n.parcelSizeS,
  'M' => l10n.parcelSizeM,
  'L' => l10n.parcelSizeL,
  'XL' => l10n.parcelSizeXL,
  _ => code,
};

String parcelOutcomeLabel(AppLocalizations l10n, ParcelInfo p) =>
    switch (p.outcome) {
      ParcelOutcome.delivered => l10n.parcelOutcomeDelivered,
      ParcelOutcome.returning => l10n.parcelOutcomeReturning,
      ParcelOutcome.returned => l10n.parcelOutcomeReturned,
      ParcelOutcome.pending =>
        p.pickedUp
            ? l10n.parcelOutcomeInTransit
            : l10n.parcelOutcomeWaitingPickup,
    };

String parcelFailReasonLabel(AppLocalizations l10n, ParcelFailReason r) =>
    switch (r) {
      ParcelFailReason.recipientUnreachable => l10n.parcelFailUnreachable,
      ParcelFailReason.recipientRefused => l10n.parcelFailRefused,
      ParcelFailReason.addressWrong => l10n.parcelFailAddress,
      ParcelFailReason.itemDamaged => l10n.parcelFailDamaged,
      ParcelFailReason.other => l10n.parcelFailOther,
    };

/// Server error codes the parcel screens explain; anything else is generic.
String parcelErrorLabel(AppLocalizations l10n, String? code) => switch (code) {
  'PARCEL_NO_VEHICLE' => l10n.parcelErrorNoVehicle,
  'PARCEL_TOO_HEAVY' => l10n.parcelErrorTooHeavy,
  'PARCEL_CODE_INVALID' ||
  'PARCEL_RECIPIENT_CODE_REQUIRED' => l10n.parcelErrorRecipientCode,
  'PARCEL_CODE_LOCKED' => l10n.parcelErrorCodeLocked,
  'PARCEL_SIZE_UNAVAILABLE' => l10n.parcelErrorSizeUnavailable,
  'PARCEL_PAYER_METHOD' => l10n.parcelErrorPayerMethod,
  'DOCUMENT_INVALID' || 'UPLOAD_TOO_LARGE' => l10n.parcelErrorPhoto,
  'PARCEL_STATE' || 'RIDE_INVALID_STATE' => l10n.parcelErrorState,
  'NETWORK' => l10n.parcelErrorNetwork,
  _ => l10n.parcelErrorGeneric,
};

/// "Gói hàng · Vừa · 2.5 kg" — driver job card / incoming alert badge.
String parcelBadgeText(
  AppLocalizations l10n,
  String? sizeClass,
  double? weightKg,
) => [
  l10n.parcelDriverBadge,
  if (sizeClass != null) parcelSizeLabel(l10n, sizeClass),
  if (weightKg != null) '${weightKg.toStringAsFixed(1)} kg',
].join(' · ');
