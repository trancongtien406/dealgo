import 'package:flutter/material.dart';

import '../../../../core/design_system/icons/dealgo_icons.dart';
import '../../../../core/design_system/tokens/dealgo_tokens.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../driver_card/presentation/driver_card_tile.dart';
import '../../../rating/domain/service_rating.dart';
import '../../domain/entities/food_models.dart';

/// Browse groups shown as round chips; each maps to backend category codes.
enum FoodStoreGroup {
  near(
    'near',
    DealGoIcons.pinFilled,
    Color(0xFFF3EAFF),
    DealGoColors.primary,
    {},
  ),
  vietnamese(
    'vietnamese',
    DealGoIcons.food,
    Color(0xFFFFF1E6),
    Color(0xFFEA580C),
    {'pho', 'bun', 'noodles', 'rice', 'com', 'banh_mi', 'vietnamese'},
  ),
  tea('tea', DealGoIcons.coffee, Color(0xFFFFEEF6), Color(0xFFDB2777), {
    'tea',
    'milk_tea',
    'tra_sua',
  }),
  fastFood(
    'fast',
    DealGoIcons.burger,
    Color(0xFFE7F8EC),
    DealGoColors.brandGreen,
    {'fastfood', 'fast_food', 'chicken', 'pizza', 'burger', 'snack'},
  ),
  cafe('cafe', DealGoIcons.coffee, Color(0xFFE8F1FF), Color(0xFF2563EB), {
    'cafe',
    'coffee',
  });

  const FoodStoreGroup(
    this.wire,
    this.icon,
    this.background,
    this.color,
    this.codes,
  );

  final String wire;
  final IconData icon;
  final Color background;
  final Color color;

  /// Empty = every store ("near me" keeps the backend's distance order).
  final Set<String> codes;

  static FoodStoreGroup? fromWire(String? value) {
    for (final group in values) {
      if (group.wire == value) return group;
    }
    return null;
  }

  bool matches(FoodStoreSummary store) =>
      codes.isEmpty || codes.contains(store.category?.toLowerCase());

  String label(AppLocalizations l10n) => switch (this) {
    near => l10n.foodGroupNear,
    vietnamese => l10n.foodGroupVietnamese,
    tea => l10n.foodGroupTea,
    fastFood => l10n.foodGroupFastFood,
    cafe => l10n.foodGroupCafe,
  };
}

/// Localized label for a backend category code; unknown codes are shown as typed
/// by the merchant, null codes show nothing.
String? storeCategoryLabel(AppLocalizations l10n, String? code) {
  final value = code?.trim().toLowerCase();
  if (value == null || value.isEmpty) return null;
  return switch (value) {
    'pho' => l10n.storeCategoryPho,
    'bun' || 'noodles' => l10n.storeCategoryNoodles,
    'rice' || 'com' => l10n.storeCategoryRice,
    'banh_mi' => l10n.storeCategoryBanhMi,
    'cafe' || 'coffee' => l10n.storeCategoryCafe,
    'tea' || 'milk_tea' || 'tra_sua' => l10n.storeCategoryTea,
    'fastfood' ||
    'fast_food' ||
    'burger' ||
    'pizza' ||
    'chicken' => l10n.storeCategoryFastFood,
    'snack' => l10n.storeCategorySnack,
    'mart' || 'grocery' => l10n.storeCategoryMart,
    'vietnamese' => l10n.foodGroupVietnamese,
    _ => value[0].toUpperCase() + value.substring(1).replaceAll('_', ' '),
  };
}

/// "1,2 km" with the locale's decimal separator.
String formatDistanceKm(BuildContext context, double km) {
  final text = km < 10 ? km.toStringAsFixed(1) : km.toStringAsFixed(0);
  final local = Localizations.localeOf(context).languageCode == 'vi'
      ? text.replaceAll('.', ',')
      : text;
  return AppLocalizations.of(context).storeDistance(local);
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

/// One line under a store name: rating · category · distance, each only when real.
class StoreMetaLine extends StatelessWidget {
  const StoreMetaLine({required this.store, this.rating, super.key});

  final FoodStoreSummary store;
  final StoreRating? rating;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final style = Theme.of(context).textTheme.bodySmall;
    final ratingText = storeRatingText(context, rating);
    final distance = store.distanceKm;
    final rest = [
      ?storeCategoryLabel(l10n, store.category),
      if (distance != null) formatDistanceKm(context, distance),
    ];
    // DEC-PROD-027: closed/paused stores stay listed (sorted last) with a label.
    final closedLabel = switch (store.closedReason) {
      StoreClosedReason.paused => l10n.foodStorePausedLabel,
      StoreClosedReason.closed => l10n.foodStoreClosedLabel,
      null => null,
    };
    if (ratingText == null && rest.isEmpty && closedLabel == null) {
      return const SizedBox.shrink();
    }
    return Text.rich(
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
                DealGoIcons.star,
                size: 12,
                color: DealGoColors.amber,
              ),
            ),
            TextSpan(text: ' $ratingText'),
            if (rest.isNotEmpty) const TextSpan(text: ' · '),
          ],
          TextSpan(text: rest.join(' · ')),
        ],
      ),
      key: Key('store-meta-${store.id}'),
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: style,
    );
  }
}
