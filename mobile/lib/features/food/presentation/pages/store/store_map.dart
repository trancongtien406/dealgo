part of '../food_store_page.dart';

class _StoreMapCard extends StatelessWidget {
  const _StoreMapCard({
    required this.store,
    required this.onOpenMaps,
    this.height = 160,
  });

  final FoodStoreDetail store;
  final VoidCallback onOpenMaps;
  final double height;

  @override
  Widget build(BuildContext context) {
    final lat = store.lat;
    final lng = store.lng;
    if (lat == null || lng == null) return const SizedBox.shrink();
    final l10n = AppLocalizations.of(context);
    final textTheme = Theme.of(context).textTheme;
    final center = MapLatLng(lat: lat, lng: lng);
    final radius = BorderRadius.circular(DealGoRadius.card);
    return Semantics(
      button: true,
      label: l10n.foodStoreOpenInMaps,
      child: GestureDetector(
        onTap: onOpenMaps,
        child: ClipRRect(
          borderRadius: radius,
          child: SizedBox(
            key: const Key('food-store-map'),
            height: height,
            width: double.infinity,
            child: Stack(
              fit: StackFit.expand,
              children: [
                context.watch<MapPort>().buildMap(
                  center: center,
                  markers: [center],
                  stopStyle: MapStopStyle.food,
                  fitPadding: const EdgeInsets.all(44),
                ),
                Positioned(
                  left: DealGoSpacing.s8,
                  right: DealGoSpacing.s8,
                  bottom: DealGoSpacing.s8,
                  child: Material(
                    color: DealGoColors.card,
                    borderRadius: BorderRadius.circular(DealGoRadius.input),
                    elevation: 2,
                    shadowColor: DealGoColors.border,
                    clipBehavior: Clip.antiAlias,
                    child: InkWell(
                      key: const Key('food-store-map-open'),
                      onTap: onOpenMaps,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: DealGoSpacing.s12,
                          vertical: DealGoSpacing.s8,
                        ),
                        child: Row(
                          children: [
                            const Icon(
                              DealGoIcons.pin,
                              size: 16,
                              color: DealGoColors.primary,
                            ),
                            const SizedBox(width: DealGoSpacing.s6),
                            Expanded(
                              child: Text(
                                store.addressLabel?.trim().isNotEmpty == true
                                    ? store.addressLabel!
                                    : l10n.foodStoreOpenInMaps,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: textTheme.bodySmall?.copyWith(
                                  color: DealGoColors.text,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                            const SizedBox(width: DealGoSpacing.s8),
                            Text(
                              l10n.foodStoreDirections,
                              style: textTheme.labelSmall?.copyWith(
                                color: DealGoColors.primary,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            const Icon(
                              DealGoIcons.chevronRight,
                              size: 16,
                              color: DealGoColors.primary,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Address-only location block for stores the merchant has not pinned yet:
/// customers still need a way to see where the store is and open directions.
class _StoreLocationCard extends StatelessWidget {
  const _StoreLocationCard({required this.address, required this.onOpenMaps});

  final String address;
  final VoidCallback onOpenMaps;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final textTheme = Theme.of(context).textTheme;
    return Material(
      color: DealGoColors.subtlePurple,
      borderRadius: BorderRadius.circular(DealGoRadius.card),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        key: const Key('food-store-map'),
        onTap: onOpenMaps,
        child: Padding(
          padding: const EdgeInsets.all(DealGoSpacing.s12),
          child: Row(
            children: [
              const Icon(
                DealGoIcons.pin,
                size: 18,
                color: DealGoColors.primary,
              ),
              const SizedBox(width: DealGoSpacing.s8),
              Expanded(
                child: Text(
                  address,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: textTheme.bodySmall?.copyWith(
                    color: DealGoColors.text,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              const SizedBox(width: DealGoSpacing.s8),
              Text(
                l10n.foodStoreDirections,
                style: textTheme.labelSmall?.copyWith(
                  color: DealGoColors.primary,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const Icon(
                DealGoIcons.chevronRight,
                size: 16,
                color: DealGoColors.primary,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Positive tags repeated in the loaded reviews, most mentioned first.
List<(RatingTag, int)> _praisedTags(StoreReviews? reviews) {
  if (reviews == null) return const [];
  final counts = <RatingTag, int>{};
  for (final review in reviews.items) {
    for (final tag in review.tags) {
      if (tag.positive) counts[tag] = (counts[tag] ?? 0) + 1;
    }
  }
  final ranked = [
    for (final entry in counts.entries)
      if (entry.value >= 2) (entry.key, entry.value),
  ]..sort((a, b) => b.$2.compareTo(a.$2));
  return ranked.take(3).toList(growable: false);
}

/// The store's live offers as voucher tickets: a swipeable strip, and
/// "Xem tất cả" for the full list in a sheet. "Dùng" attaches the code to
/// this store's cart; checkout prices it again.
