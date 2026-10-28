import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../../core/design_system/icons/dealgo_icons.dart';
import '../../../../core/design_system/tokens/dealgo_tokens.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../driver_card/presentation/driver_card_tile.dart';
import '../../../rating/domain/service_rating.dart';
import '../../domain/entities/food_models.dart';
import '../../domain/entities/food_money.dart';
import '../../../promotion/domain/entities/voucher_discount.dart';
import '../food_categories_store.dart';

/// "1,2 km" with the locale's decimal separator.
String formatDistanceKm(BuildContext context, double km) {
  final text = km < 10 ? km.toStringAsFixed(1) : km.toStringAsFixed(0);
  final local = Localizations.localeOf(context).languageCode == 'vi'
      ? text.replaceAll('.', ',')
      : text;
  return AppLocalizations.of(context).storeDistance(local);
}

/// The fetched summary when there is one, else the rating the list sent
/// inline. Null when neither is known.
StoreRating? storeRatingOf(FoodStoreSummary store, [StoreRating? fetched]) {
  if (fetched != null) return fetched;
  final count = store.ratingCount;
  if (count == null) return null;
  return StoreRating(
    storeId: store.id,
    count: count,
    average: store.ratingAverage,
  );
}

/// Rating text from the backend summary: "4,8 (12)", "3 đánh giá" while the
/// average is still hidden, or "Quán mới" with no ratings. Null = not loaded.
String? storeRatingText(BuildContext context, StoreRating? rating) {
  if (rating == null) return null;
  final l10n = AppLocalizations.of(context);
  final average = rating.average;
  if (rating.count == 0) return l10n.storeRatingNew;
  if (average == null) return l10n.storeRatingFew(rating.count);
  return l10n.storeRatingValue(
    formatRatingAverage(context, average),
    rating.count,
  );
}

/// "Giảm 20%", "Giảm 20%, tối đa 30.000 ₫" or "Giảm 15.000 ₫".
String storeOfferLabel(AppLocalizations l10n, StoreOffer offer) =>
    switch (offer.kind) {
      StoreOfferKind.percentage when offer.maxDiscountVnd != null =>
        l10n.voucherPercentMax(
          offer.discountValue,
          formatVnd(offer.maxDiscountVnd!),
        ),
      StoreOfferKind.percentage => l10n.voucherPercent(offer.discountValue),
      StoreOfferKind.fixedAmount => l10n.voucherFixed(
        formatVnd(offer.discountValue),
      ),
    };

/// Short headline for badges: "-20%" or "-15K".
String storeOfferShort(StoreOffer offer) => switch (offer.kind) {
  StoreOfferKind.percentage => '-${offer.discountValue}%',
  StoreOfferKind.fixedAmount =>
    offer.discountValue >= 1000 && offer.discountValue % 1000 == 0
        ? '-${offer.discountValue ~/ 1000}K'
        : '-${formatVnd(offer.discountValue)}',
};

/// Compact money for ticket headlines: 15000 → "15K".
String shortVnd(int vnd) =>
    vnd >= 1000 && vnd % 1000 == 0 ? '${vnd ~/ 1000}K' : formatVnd(vnd);

/// Ticket headline: "Giảm 20%" or "Giảm 15K".
String storeOfferHeadline(AppLocalizations l10n, StoreOffer offer) =>
    switch (offer.kind) {
      StoreOfferKind.percentage => l10n.voucherPercent(offer.discountValue),
      StoreOfferKind.fixedAmount => l10n.voucherFixed(
        shortVnd(offer.discountValue),
      ),
    };

/// Every condition of an offer, in full: minimum order, cap, expiry and
/// uses left — each only when it applies.
List<String> storeOfferConditions(
  AppLocalizations l10n,
  StoreOffer offer, {
  required String locale,
}) => [
  if (offer.minOrderVnd > 0) l10n.voucherMinOrder(formatVnd(offer.minOrderVnd)),
  if (offer.kind == StoreOfferKind.percentage && offer.maxDiscountVnd != null)
    l10n.voucherCap(formatVnd(offer.maxDiscountVnd!)),
  l10n.voucherEnds(DateFormat('dd/MM/yyyy', locale).format(offer.endsAt)),
  if (offer.remainingUses != null) l10n.voucherUsesLeft(offer.remainingUses!),
];

/// Client estimate of what [offer] takes off [subtotalVnd]; 0 below its
/// minimum. Percentages round down to 1.000đ like the server, which still
/// prices the code at placement.
int storeOfferSaving(StoreOffer offer, int subtotalVnd) {
  if (subtotalVnd <= 0 || subtotalVnd < offer.minOrderVnd) return 0;
  final saving = switch (offer.kind) {
    StoreOfferKind.percentage => percentVoucherDiscountVnd(
      subtotalVnd,
      offer.discountValue,
      offer.maxDiscountVnd,
    ),
    StoreOfferKind.fixedAmount => offer.discountValue,
  };
  return saving.clamp(0, subtotalVnd);
}

/// Red pill with the store's best offer; callers only build it when
/// [FoodStoreSummary.offers] is not empty.
class StoreOfferBadge extends StatelessWidget {
  const StoreOfferBadge({required this.offer, this.compact = false, super.key});

  final StoreOffer offer;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return DecoratedBox(
      decoration: BoxDecoration(
        color: DealGoColors.danger,
        borderRadius: BorderRadius.circular(DealGoRadius.pill),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: DealGoSpacing.s8,
          vertical: 3,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(DealGoIcons.tag, size: 12, color: Colors.white),
            const SizedBox(width: 4),
            Text(
              compact ? storeOfferShort(offer) : storeOfferLabel(l10n, offer),
              style: const TextStyle(
                color: Colors.white,
                fontSize: 11,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Lines under a store name: closed label · rating · category · distance,
/// then ETA and the "from" delivery fee — each only when real. Text wraps
/// instead of truncating.
class StoreMetaLine extends StatelessWidget {
  const StoreMetaLine({required this.store, this.rating, super.key});

  final FoodStoreSummary store;
  final StoreRating? rating;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final style = Theme.of(context).textTheme.bodySmall;
    final ratingText = storeRatingText(context, storeRatingOf(store, rating));
    final distance = store.distanceKm;
    final rest = [
      ?foodCategoryLabel(context, store.category),
      if (distance != null) formatDistanceKm(context, distance),
    ];
    // DEC-PROD-027: closed/paused stores stay listed (sorted last) with a label.
    final closedLabel = switch (store.closedReason) {
      StoreClosedReason.paused => l10n.foodStorePausedLabel,
      StoreClosedReason.closed => l10n.foodStoreClosedLabel,
      null => null,
    };
    final eta = store.etaMinutes;
    final fee = store.deliveryFeeFromVnd;
    final hasFirst =
        ratingText != null || rest.isNotEmpty || closedLabel != null;
    if (!hasFirst && eta == null && fee == null) {
      return const SizedBox.shrink();
    }
    final first = Text.rich(
      TextSpan(
        children: [
          if (closedLabel != null) ...[
            TextSpan(
              text: closedLabel,
              style: const TextStyle(
                color: DealGoColors.danger,
                fontWeight: FontWeight.w700,
              ),
            ),
            if (ratingText != null || rest.isNotEmpty)
              const TextSpan(text: ' · '),
          ],
          if (ratingText != null) ...[
            const WidgetSpan(
              alignment: PlaceholderAlignment.middle,
              child: Icon(
                DealGoIcons.starFilled,
                size: 12,
                color: DealGoColors.amber,
              ),
            ),
            TextSpan(
              text: ' $ratingText',
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
            if (rest.isNotEmpty) const TextSpan(text: ' · '),
          ],
          TextSpan(text: rest.join(' · ')),
        ],
      ),
      key: Key('store-meta-${store.id}'),
      style: style,
    );
    if (eta == null && fee == null) return first;
    final second = Text.rich(
      TextSpan(
        children: [
          if (eta != null) ...[
            const WidgetSpan(
              alignment: PlaceholderAlignment.middle,
              child: Icon(
                DealGoIcons.clock,
                size: 12,
                color: DealGoColors.textTertiary,
              ),
            ),
            TextSpan(text: ' ${l10n.foodStorePrepChip(eta)}'),
            if (fee != null) const TextSpan(text: ' · '),
          ],
          if (fee != null) ...[
            WidgetSpan(
              alignment: PlaceholderAlignment.middle,
              child: Icon(
                DealGoIcons.motorbike,
                size: 12,
                color: fee == 0
                    ? DealGoColors.brandGreen
                    : DealGoColors.textTertiary,
              ),
            ),
            if (fee == 0)
              TextSpan(
                text: ' ${l10n.foodStoreFeeFree}',
                style: const TextStyle(
                  color: DealGoColors.brandGreen,
                  fontWeight: FontWeight.w700,
                ),
              )
            else
              TextSpan(text: ' ${l10n.foodStoreFeeFrom(formatVnd(fee))}'),
          ],
        ],
      ),
      key: Key('store-eta-fee-${store.id}'),
      style: style,
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (hasFirst) first,
        if (hasFirst) const SizedBox(height: 2),
        second,
      ],
    );
  }
}
