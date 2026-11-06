import 'package:flutter/material.dart';

import '../../../../core/design_system/components/dealgo_haptics.dart';
import '../../../../core/design_system/tokens/dealgo_tokens.dart';
import '../../../../core/design_system/tokens/dealgo_type_scale.dart';
import '../../../../core/motion/dealgo_motion_widgets.dart';
import '../../../rating/domain/service_rating.dart';
import '../../domain/entities/food_models.dart';
import 'food_badges.dart';
import 'food_category_tile.dart';
import 'food_widgets.dart';
import 'store_meta.dart';

enum FoodStoreCardVariant { feed, compact }

/// The single store row used by discovery, category, search and home.
///
/// [FoodStoreCardVariant.feed] carries up to two signature dishes;
/// [FoodStoreCardVariant.compact] is the short row for side rails.
class FoodStoreCard extends StatelessWidget {
  const FoodStoreCard({
    required this.store,
    required this.onTap,
    this.rating,
    this.variant = FoodStoreCardVariant.feed,
    super.key,
  });

  final FoodStoreSummary store;
  final StoreRating? rating;
  final VoidCallback onTap;
  final FoodStoreCardVariant variant;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final closed = store.closedReason != null;
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
            child: Padding(
              padding: const EdgeInsets.all(DealGoDensity.cardPad),
              child: variant == FoodStoreCardVariant.compact
                  ? _CompactBody(store: store, rating: rating)
                  : _FeedBody(
                      store: store,
                      rating: rating,
                      textTheme: textTheme,
                      closed: closed,
                    ),
            ),
          ),
        ),
      ),
    );
  }
}

class _FeedBody extends StatelessWidget {
  const _FeedBody({
    required this.store,
    required this.rating,
    required this.textTheme,
    required this.closed,
  });

  final FoodStoreSummary store;
  final StoreRating? rating;
  final TextTheme textTheme;
  final bool closed;

  @override
  Widget build(BuildContext context) {
    final dishes = store.featuredItems.take(2).toList(growable: false);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Opacity(
          opacity: closed ? 0.5 : 1,
          child: FoodThumb(
            size: 88,
            imageUrl: store.imageUrl,
            placeholderAsset: foodDishFallbackImage(store.category),
          ),
        ),
        const SizedBox(width: DealGoSpacing.s12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(store.name, style: DealGoType.subtitle(textTheme)),
              const SizedBox(height: DealGoDensity.metaGap),
              FoodMetaLine(store: store, rating: rating),
              if (store.offers.isNotEmpty || store.minOrderVnd > 0) ...[
                const SizedBox(height: DealGoSpacing.s8),
                FoodStoreBadges(store: store),
              ],
              for (final dish in dishes)
                Padding(
                  padding: const EdgeInsets.only(top: DealGoSpacing.s4),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          dish.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: DealGoType.body(
                            textTheme,
                          ).copyWith(color: DealGoColors.text),
                        ),
                      ),
                      const SizedBox(width: DealGoSpacing.s8),
                      FoodPriceText(
                        priceVnd: dish.priceVnd,
                        originalPriceVnd: dish.originalPriceVnd,
                        size: 12,
                        showPercent: false,
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

class _CompactBody extends StatelessWidget {
  const _CompactBody({required this.store, required this.rating});

  final FoodStoreSummary store;
  final StoreRating? rating;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Row(
      children: [
        FoodThumb(
          size: 64,
          imageUrl: store.imageUrl,
          placeholderAsset: foodDishFallbackImage(store.category),
        ),
        const SizedBox(width: DealGoSpacing.s12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                store.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: DealGoType.subtitle(textTheme),
              ),
              const SizedBox(height: DealGoDensity.metaGap),
              FoodMetaLine(store: store, rating: rating, maxLines: 2),
            ],
          ),
        ),
      ],
    );
  }
}
