import 'package:flutter/material.dart';

import '../../../../core/design_system/icons/dealgo_icons.dart';
import '../../../../core/design_system/tokens/dealgo_tokens.dart';
import '../../../../l10n/app_localizations.dart';
import '../../domain/entities/food_models.dart';
import '../../domain/entities/food_money.dart';
import 'store_meta.dart';

/// Small rounded label used for dish and store badges.
class FoodPill extends StatelessWidget {
  const FoodPill({
    required this.label,
    required this.foreground,
    required this.background,
    this.icon,
    super.key,
  });

  final String label;
  final Color foreground;
  final Color background;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: background,
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
            if (icon != null) ...[
              Icon(icon, size: 12, color: foreground),
              const SizedBox(width: 3),
            ],
            Text(
              label,
              style: TextStyle(
                color: foreground,
                fontSize: 11,
                height: 1.2,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class FoodBestSellerBadge extends StatelessWidget {
  const FoodBestSellerBadge({super.key});

  @override
  Widget build(BuildContext context) => FoodPill(
    label: AppLocalizations.of(context).foodBadgeBestSeller,
    foreground: DealGoColors.warning,
    background: DealGoColors.amberSurface,
    icon: DealGoIcons.trending,
  );
}

class FoodNewBadge extends StatelessWidget {
  const FoodNewBadge({super.key});

  @override
  Widget build(BuildContext context) => FoodPill(
    label: AppLocalizations.of(context).foodBadgeNew,
    foreground: Colors.white,
    background: DealGoColors.brandGreen,
  );
}

/// "Đơn tối thiểu 40.000 ₫" — only for stores with a minimum.
class FoodMinOrderPill extends StatelessWidget {
  const FoodMinOrderPill({required this.amountVnd, super.key});

  final int amountVnd;

  @override
  Widget build(BuildContext context) => FoodPill(
    label: AppLocalizations.of(context).foodStoreMinOrder(formatVnd(amountVnd)),
    foreground: DealGoColors.primaryDeep,
    background: DealGoColors.subtlePurple,
    icon: DealGoIcons.shoppingBag,
  );
}

/// "-15%" next to a struck-through original price.
class FoodDiscountPill extends StatelessWidget {
  const FoodDiscountPill({required this.percent, super.key});

  final int percent;

  @override
  Widget build(BuildContext context) => FoodPill(
    label: '-$percent%',
    foreground: Colors.white,
    background: DealGoColors.danger,
  );
}

/// Dish badges that have real content: "Mới" (added within 14 days) and
/// "Bán chạy" (the store's top sellers with at least one sale).
class FoodItemBadges extends StatelessWidget {
  const FoodItemBadges({
    required this.isNew,
    required this.bestSeller,
    super.key,
  });

  final bool isNew;
  final bool bestSeller;

  @override
  Widget build(BuildContext context) {
    if (!isNew && !bestSeller) return const SizedBox.shrink();
    return Wrap(
      spacing: DealGoSpacing.s4,
      runSpacing: DealGoSpacing.s4,
      children: [
        if (bestSeller) const FoodBestSellerBadge(),
        if (isNew) const FoodNewBadge(),
      ],
    );
  }
}

/// Price in brand purple, then the original price struck through and the
/// percent off when the merchant set one.
class FoodPriceText extends StatelessWidget {
  const FoodPriceText({
    required this.priceVnd,
    this.originalPriceVnd,
    this.size = 15,
    this.color = DealGoColors.primary,
    this.showPercent = true,
    super.key,
  });

  final int priceVnd;
  final int? originalPriceVnd;
  final double size;
  final Color color;
  final bool showPercent;

  @override
  Widget build(BuildContext context) {
    final original = originalPriceVnd;
    final discounted = original != null && original > priceVnd;
    final percent = discounted
        ? ((original - priceVnd) * 100 / original).round()
        : 0;
    return Wrap(
      crossAxisAlignment: WrapCrossAlignment.center,
      spacing: DealGoSpacing.s6,
      runSpacing: DealGoSpacing.s2,
      children: [
        Text(
          formatVnd(priceVnd),
          style: TextStyle(
            color: discounted ? DealGoColors.danger : color,
            fontSize: size,
            fontWeight: FontWeight.w800,
          ),
        ),
        if (discounted) ...[
          Text(
            formatVnd(original),
            style: TextStyle(
              color: DealGoColors.textTertiary,
              fontSize: size - 3,
              fontWeight: FontWeight.w500,
              decoration: TextDecoration.lineThrough,
              decorationColor: DealGoColors.textTertiary,
            ),
          ),
          if (showPercent && percent > 0) FoodDiscountPill(percent: percent),
        ],
      ],
    );
  }
}

/// Offer and minimum-order pills under a store card; only the
/// ones that apply.
class FoodStoreBadges extends StatelessWidget {
  const FoodStoreBadges({
    required this.store,
    this.showOffer = true,
    super.key,
  });

  final FoodStoreSummary store;
  final bool showOffer;

  @override
  Widget build(BuildContext context) {
    final offer = showOffer && store.offers.isNotEmpty
        ? store.offers.first
        : null;
    final minOrder = store.minOrderVnd;
    if (offer == null && minOrder <= 0) {
      return const SizedBox.shrink();
    }
    return Wrap(
      key: Key('food-store-badges-${store.id}'),
      spacing: DealGoSpacing.s4,
      runSpacing: DealGoSpacing.s4,
      children: [
        if (offer != null) StoreOfferBadge(offer: offer),
        if (minOrder > 0) FoodMinOrderPill(amountVnd: minOrder),
      ],
    );
  }
}

/// "HH:mm" for now + [minutes], in the device's local time.
String foodEtaClock(BuildContext context, int minutes, {DateTime? now}) {
  final at = (now ?? DateTime.now()).add(Duration(minutes: minutes));
  return MaterialLocalizations.of(context)
      .formatTimeOfDay(TimeOfDay.fromDateTime(at), alwaysUse24HourFormat: true);
}

/// Green "Dự kiến giao lúc 12:45" line.
class FoodEtaLine extends StatelessWidget {
  const FoodEtaLine({required this.minutes, this.now, super.key});

  final int minutes;
  final DateTime? now;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return DecoratedBox(
      decoration: BoxDecoration(
        color: DealGoColors.greenSurface,
        borderRadius: BorderRadius.circular(DealGoRadius.input),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: DealGoSpacing.s12,
          vertical: DealGoSpacing.s8,
        ),
        child: Row(
          children: [
            const Icon(
              DealGoIcons.timer,
              size: 18,
              color: DealGoColors.brandGreen,
            ),
            const SizedBox(width: DealGoSpacing.s8),
            Expanded(
              child: Text(
                l10n.foodEtaArriveAt(foodEtaClock(context, minutes, now: now)),
                key: const Key('food-eta-line'),
                style: const TextStyle(
                  color: DealGoColors.brandGreen,
                  fontWeight: FontWeight.w700,
                  fontSize: 13,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// The store's top 3 sellers with at least one sale ("Bán chạy").
Set<String> foodBestSellerIds(List<FoodMenuItem> items) {
  final sold = [
    for (final item in items)
      if (item.soldCount > 0) item,
  ]..sort((a, b) => b.soldCount.compareTo(a.soldCount));
  return {for (final item in sold.take(3)) item.id};
}
