part of '../food_store_page.dart';

class _Hero extends StatelessWidget {
  const _Hero({required this.store});

  final FoodStoreDetail store;

  @override
  Widget build(BuildContext context) {
    final gallery = <String>[
      for (final item in store.items)
        if ((item.imageUrl ?? '').isNotEmpty) item.imageUrl!,
    ];
    // Merchant cover photo; without one, the first dish photo, then the logo.
    final cover =
        store.coverUrl ?? (gallery.isNotEmpty ? gallery.first : store.logoUrl);
    final logo = resolveMediaUrl(store.logoUrl);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Stack(
          clipBehavior: Clip.none,
          children: [
            FoodCoverImage(
              key: const Key('food-store-cover'),
              imageUrl: cover,
              aspectRatio: 2,
            ),
            if (logo != null && logo.isNotEmpty)
              Positioned(
                left: DealGoSpacing.s12,
                bottom: DealGoSpacing.s12,
                child: Container(
                  key: const Key('food-store-logo'),
                  width: 56,
                  height: 56,
                  clipBehavior: Clip.antiAlias,
                  decoration: BoxDecoration(
                    color: DealGoColors.card,
                    borderRadius: BorderRadius.circular(DealGoRadius.input),
                    border: Border.all(color: Colors.white, width: 2),
                    boxShadow: DealGoShadows.card,
                  ),
                  child: DealGoNetworkImage(
                    logo,
                    fit: BoxFit.cover,
                    fallback: const SizedBox.shrink(),
                  ),
                ),
              ),
          ],
        ),
        StoreTrustStrip(
          closesAtToday: store.closesAtToday,
          feeFromVnd: store.deliveryFeeFromVnd,
        ),
      ],
    );
  }
}

class _StoreHeading extends StatelessWidget {
  const _StoreHeading({
    required this.store,
    required this.onRatingTap,
    required this.onOpenMaps,
    this.rating,
    this.reviews,
    this.distanceKm,
  });

  final VoidCallback onOpenMaps;
  final FoodStoreDetail store;
  final StoreRating? rating;
  final StoreReviews? reviews;
  final double? distanceKm;
  final VoidCallback onRatingTap;

  @override
  Widget build(BuildContext context) {
    final open = store.openNow && store.items.any((item) => item.available);
    final today = store.schedule.hoursConfigured
        ? store.schedule.day(
            DateTime.now().toUtc().add(const Duration(hours: 7)).weekday,
          )
        : null;
    final textTheme = Theme.of(context).textTheme;
    final l10n = AppLocalizations.of(context);
    final prep = store.estimatedPrepMinutes;
    final distance = distanceKm;
    // Same estimate as the list: prep + 3 min per km.
    final eta = prep != null && distance != null
        ? prep + (distance * 3).round()
        : null;
    final category = foodCategoryLabel(context, store.category);
    final ratingText = storeRatingText(context, rating);
    final address = store.addressLabel?.trim() ?? '';
    final sold = store.items.fold<int>(0, (sum, item) => sum + item.soldCount);
    final tags = _praisedTags(reviews);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(child: Text(store.name, style: textTheme.titleLarge)),
            const SizedBox(width: DealGoSpacing.s8),
            DecoratedBox(
              decoration: BoxDecoration(
                color: open
                    ? DealGoColors.greenSurface
                    : DealGoColors.warningSurface,
                borderRadius: BorderRadius.circular(999),
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: DealGoSpacing.s12,
                  vertical: DealGoSpacing.s4,
                ),
                child: Text(
                  open
                      ? l10n.foodStoreOpen
                      : store.closedReason == StoreClosedReason.closed
                      ? l10n.foodStoreClosedLabel
                      : l10n.foodStorePaused,
                  style: textTheme.labelSmall?.copyWith(
                    color: open
                        ? DealGoColors.brandGreen
                        : DealGoColors.warning,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
          ],
        ),
        if (category != null) ...[
          const SizedBox(height: 2),
          Text(category, style: textTheme.bodySmall),
        ],
        if (store.description != null) ...[
          const SizedBox(height: DealGoSpacing.s6),
          Text(
            store.description!,
            key: const Key('food-store-description'),
            style: textTheme.bodyMedium?.copyWith(
              color: DealGoColors.textSecondary,
            ),
          ),
        ],
        if (address.isNotEmpty) ...[
          const SizedBox(height: DealGoSpacing.s6),
          InkWell(
            key: const Key('food-store-address-link'),
            onTap: onOpenMaps,
            borderRadius: BorderRadius.circular(DealGoRadius.input),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 2),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.only(top: 1),
                    child: Icon(
                      DealGoIcons.pin,
                      size: 14,
                      color: DealGoColors.textSecondary,
                    ),
                  ),
                  const SizedBox(width: DealGoSpacing.s4),
                  Expanded(
                    child: Text(
                      address,
                      key: const Key('food-store-address'),
                      style: textTheme.bodySmall,
                    ),
                  ),
                  const SizedBox(width: DealGoSpacing.s4),
                  Text(
                    l10n.foodStoreDirections,
                    style: textTheme.labelSmall?.copyWith(
                      color: DealGoColors.primary,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  Icon(
                    DealGoIcons.navigation,
                    size: 13,
                    color: DealGoColors.primary,
                  ),
                ],
              ),
            ),
          ),
        ],
        if (store.closedReason != null ||
            store.serviceMode == StoreServiceMode.busy) ...[
          const SizedBox(height: DealGoSpacing.s8),
          DealGoBanner(
            key: const Key('food-store-mode-banner'),
            tone: store.closedReason != null
                ? DealGoBannerTone.warning
                : DealGoBannerTone.info,
            message: switch (store.closedReason) {
              StoreClosedReason.paused => l10n.foodStorePausedBanner,
              StoreClosedReason.closed => l10n.foodStoreClosedBanner,
              null => l10n.foodStoreBusyBanner,
            },
          ),
        ],
        const SizedBox(height: DealGoSpacing.s12),
        Wrap(
          spacing: DealGoSpacing.s8,
          runSpacing: DealGoSpacing.s8,
          children: [
            if (ratingText != null)
              InkWell(
                key: const Key('food-store-rating'),
                onTap: onRatingTap,
                borderRadius: BorderRadius.circular(DealGoRadius.pill),
                child: FoodInfoChip(
                  label: ratingText,
                  icon: DealGoIcons.star,
                  iconColor: DealGoColors.amber,
                ),
              ),
            if (distance != null)
              Tooltip(
                message: l10n.foodStoreOpenInMaps,
                child: InkWell(
                  key: const Key('food-store-distance'),
                  onTap: onOpenMaps,
                  borderRadius: BorderRadius.circular(DealGoRadius.pill),
                  child: FoodInfoChip(
                    label: formatDistanceKm(context, distance),
                    icon: DealGoIcons.navigation,
                  ),
                ),
              ),
            if (store.openNow && prep != null)
              FoodInfoChip(
                key: const Key('food-store-prep-estimate'),
                label: l10n.foodStorePrepChip(eta ?? prep),
                icon: DealGoIcons.motorbike,
                filled: true,
              ),
            if (sold > 0)
              FoodInfoChip(
                key: const Key('food-store-sold'),
                label: l10n.foodStoreSoldTotal(sold),
                icon: DealGoIcons.trending,
              ),
            if (store.minOrderVnd > 0)
              FoodMinOrderPill(
                key: const Key('food-store-min-order'),
                amountVnd: store.minOrderVnd,
              ),
          ],
        ),
        if (store.schedule.hoursConfigured) ...[
          const SizedBox(height: DealGoSpacing.s8),
          Row(
            children: [
              Icon(
                DealGoIcons.clock,
                size: 14,
                color: DealGoColors.textSecondary,
              ),
              const SizedBox(width: DealGoSpacing.s4),
              Expanded(
                child: Text(
                  today == null
                      ? l10n.foodStoreHoursTodayOff
                      : l10n.foodStoreHoursToday(
                          today.overnight
                              ? l10n.foodStoreHoursOvernight(
                                  '${today.opensAt} – ${today.closesAt}',
                                )
                              : '${today.opensAt} – ${today.closesAt}',
                        ),
                  key: const Key('food-store-hours-today'),
                  style: textTheme.bodySmall,
                ),
              ),
            ],
          ),
        ],
        if (tags.isNotEmpty) ...[
          const SizedBox(height: DealGoSpacing.s12),
          Wrap(
            key: const Key('food-store-tags'),
            spacing: DealGoSpacing.s6,
            runSpacing: DealGoSpacing.s6,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Text(
                l10n.foodStoreTagsTitle,
                style: textTheme.labelSmall?.copyWith(
                  color: DealGoColors.textSecondary,
                  fontWeight: FontWeight.w700,
                ),
              ),
              for (final (tag, count) in tags)
                FoodPill(
                  label: '${ratingTagLabel(l10n, tag)} · $count',
                  foreground: DealGoColors.brandGreen,
                  background: DealGoColors.greenSurface,
                ),
            ],
          ),
        ],
      ],
    );
  }
}

/// Store position on the map; tapping anywhere (or the pill) opens Google Maps.
