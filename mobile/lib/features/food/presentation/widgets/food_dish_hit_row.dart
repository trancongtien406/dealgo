import 'package:flutter/material.dart';

import '../../../../core/design_system/components/dealgo_haptics.dart';
import '../../../../core/design_system/tokens/dealgo_tokens.dart';
import '../../../../core/motion/dealgo_motion_widgets.dart';
import '../../../../core/design_system/tokens/dealgo_type_scale.dart';
import '../../../../l10n/app_localizations.dart';
import '../../domain/entities/food_models.dart';
import 'food_badges.dart';
import 'food_widgets.dart';
import 'store_meta.dart';

/// One dish hit in search: photo, dish, its store and price.
class FoodDishHitRow extends StatelessWidget {
  const FoodDishHitRow({required this.hit, required this.onTap, super.key});

  final FoodDishHit hit;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final textTheme = Theme.of(context).textTheme;
    final store = hit.store;
    final item = hit.item;
    final closedLabel = switch (store.closedReason) {
      StoreClosedReason.paused => l10n.foodStorePausedLabel,
      StoreClosedReason.closed => l10n.foodStoreClosedLabel,
      null => null,
    };
    final meta = [
      ?closedLabel,
      store.name,
      if (store.distanceKm != null)
        formatDistanceKm(context, store.distanceKm!),
      if (store.etaMinutes != null) l10n.foodStorePrepChip(store.etaMinutes!),
    ].join(' · ');
    return DealGoPressScale(
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(DealGoRadius.card),
          boxShadow: DealGoShadows.card,
        ),
        child: Material(
          color: DealGoColors.card,
          borderRadius: BorderRadius.circular(DealGoRadius.card),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: () {
              DealGoHaptics.tap();
              onTap();
            },
            child: ConstrainedBox(
              constraints: const BoxConstraints(
                minHeight: DealGoDimensions.minTapTarget,
              ),
              child: Padding(
                padding: const EdgeInsets.all(DealGoSpacing.s8),
                child: Row(
                  children: [
                    FoodThumb(size: 64, imageUrl: item.imageUrl),
                    const SizedBox(width: DealGoSpacing.s12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            item.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: DealGoType.subtitle(textTheme),
                          ),
                          const SizedBox(height: DealGoDensity.metaGap),
                          Text(
                            meta,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: DealGoType.meta(textTheme)
                                .copyWith(color: DealGoColors.textSecondary),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: DealGoSpacing.s8),
                    FoodPriceText(
                      priceVnd: item.priceVnd,
                      originalPriceVnd: item.originalPriceVnd,
                      size: 14,
                      showPercent: false,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
