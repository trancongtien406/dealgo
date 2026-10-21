import '../../../../l10n/app_localizations.dart';
import '../../domain/entities/food_models.dart';

String foodRejectReasonLabel(AppLocalizations l10n, FoodRejectReason reason) =>
    switch (reason) {
      FoodRejectReason.outOfStock => l10n.foodRejectOutOfStock,
      FoodRejectReason.storeBusy => l10n.foodRejectStoreBusy,
      FoodRejectReason.storeClosing => l10n.foodRejectStoreClosing,
      FoodRejectReason.itemPriceChanged => l10n.foodRejectPriceChanged,
      FoodRejectReason.other => l10n.foodRejectOther,
    };

/// "Lý do: Hết món — ghi chú" for the customer.
String foodCancelReasonText(AppLocalizations l10n, FoodCancelReason reason) {
  final label = foodRejectReasonLabel(l10n, reason.reason);
  final note = reason.note;
  return note == null || note.isEmpty
      ? l10n.foodRejectReasonLine(label)
      : l10n.foodRejectReasonLineWithNote(label, note);
}
