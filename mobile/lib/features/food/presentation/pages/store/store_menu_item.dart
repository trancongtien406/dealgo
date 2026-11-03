part of '../food_store_page.dart';

void _showClosedHint(BuildContext context, FoodStoreDetail store) {
  final l10n = AppLocalizations.of(context);
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(
        content: Text(
          store.closedReason == StoreClosedReason.closed
              ? l10n.foodStoreClosedBanner
              : l10n.foodStorePausedBanner,
        ),
      ),
    );
}

class _MenuItem extends StatelessWidget {
  const _MenuItem({
    required this.store,
    required this.item,
    this.featured = false,
    this.bestSeller = false,
    this.compact = false,
    super.key,
  });

  final FoodStoreDetail store;
  final FoodMenuItem item;
  final bool bestSeller;

  /// Copy in the best-sellers group: its own add key and no hero flight.
  final bool featured;

  /// Narrow row beside the category rail: smaller photo, type and controls.
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final l10n = AppLocalizations.of(context);
    final description = item.description?.trim();
    final radius = BorderRadius.circular(DealGoRadius.card);
    final closed = !store.canOrder;
    final photoWidth = compact ? _menuCompactImageWidth : _menuImageWidth;
    final inset = compact ? DealGoSpacing.s8 : DealGoSpacing.s12;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: DealGoColors.card,
        borderRadius: radius,
        border: Border.all(color: DealGoColors.border),
        boxShadow: DealGoShadows.card,
      ),
      child: ClipRRect(
        borderRadius: radius,
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            key: Key('food-dish-${item.id}'),
            onTap: item.available
                ? () {
                    if (closed) {
                      _showClosedHint(context, store);
                      return;
                    }
                    openFoodItemOptions(
                      context: context,
                      store: store,
                      item: item,
                    );
                  }
                : null,
            child: Stack(
              children: [
                Padding(
                  padding: EdgeInsets.fromLTRB(
                    inset,
                    inset,
                    photoWidth + (compact ? DealGoSpacing.s6 : inset),
                    inset,
                  ),
                  child: ConstrainedBox(
                    constraints: BoxConstraints(minHeight: compact ? 104 : 92),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              item.name,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: textTheme.titleMedium?.copyWith(
                                fontSize: compact ? 14 : 15,
                                height: 1.25,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            if (item.isNew || bestSeller) ...[
                              const SizedBox(height: DealGoSpacing.s4),
                              FoodItemBadges(
                                isNew: item.isNew,
                                bestSeller: bestSeller,
                              ),
                            ],
                            if (description != null &&
                                description.isNotEmpty) ...[
                              const SizedBox(height: DealGoSpacing.s4),
                              Text(
                                description,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: textTheme.bodySmall?.copyWith(
                                  color: DealGoColors.textSecondary,
                                ),
                              ),
                            ],
                            if (item.soldCount > 0 ||
                                item.prepMinutes != null) ...[
                              const SizedBox(height: DealGoSpacing.s4),
                              if (compact)
                                Text(
                                  [
                                    if (item.soldCount > 0)
                                      l10n.foodItemSold(item.soldCount),
                                    if (item.prepMinutes != null)
                                      l10n.foodStorePrepChip(item.prepMinutes!),
                                  ].join(' · '),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: textTheme.labelSmall?.copyWith(
                                    color: DealGoColors.textSecondary,
                                  ),
                                )
                              else
                                Wrap(
                                  spacing: DealGoSpacing.s8,
                                  runSpacing: 2,
                                  crossAxisAlignment: WrapCrossAlignment.center,
                                  children: [
                                    if (item.soldCount > 0)
                                      _ItemMeta(
                                        icon: DealGoIcons.trending,
                                        label: l10n.foodItemSold(
                                          item.soldCount,
                                        ),
                                      ),
                                    if (item.prepMinutes != null)
                                      _ItemMeta(
                                        icon: DealGoIcons.clock,
                                        label: l10n.foodStorePrepChip(
                                          item.prepMinutes!,
                                        ),
                                      ),
                                  ],
                                ),
                            ],
                          ],
                        ),
                        Padding(
                          padding: const EdgeInsets.only(top: DealGoSpacing.s8),
                          child: Row(
                            children: [
                              Expanded(
                                child: FoodPriceText(
                                  key: Key('food-price-${item.id}'),
                                  priceVnd: item.priceVnd,
                                  originalPriceVnd: item.originalPriceVnd,
                                  size: compact ? 14 : 16,
                                ),
                              ),
                              if (!item.available)
                                Text(
                                  l10n.foodItemSoldOut,
                                  style: textTheme.labelSmall?.copyWith(
                                    color: DealGoColors.danger,
                                    fontWeight: FontWeight.w700,
                                  ),
                                )
                              else if (closed)
                                Text(
                                  store.closedReason == StoreClosedReason.closed
                                      ? l10n.foodStoreClosedLabel
                                      : l10n.foodStorePaused,
                                  style: textTheme.labelSmall?.copyWith(
                                    color: DealGoColors.danger,
                                    fontWeight: FontWeight.w700,
                                  ),
                                )
                              else
                                _MenuAddControl(
                                  store: store,
                                  item: item,
                                  compact: compact,
                                  keyPrefix: featured
                                      ? 'food-best-add'
                                      : 'food-add',
                                ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                Positioned(
                  top: 0,
                  right: 0,
                  bottom: 0,
                  width: photoWidth,
                  child: KeyedSubtree(
                    key: Key('food-menu-photo-${item.id}'),
                    child: _photo(context, l10n),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// Full-height dish photo; only items that open the options page fly it.
  Widget _photo(BuildContext context, AppLocalizations l10n) {
    final resolved = resolveMediaUrl(item.imageUrl);
    final photoCount = foodDishGalleryImages(
      imageUrls: item.imageUrls,
      fallbackImageUrl: item.imageUrl,
    ).length;
    final placeholder = Image.asset(
      foodDishFallbackImage(store.category),
      fit: BoxFit.cover,
      width: double.infinity,
      height: double.infinity,
      errorBuilder: (context, error, stack) =>
          ColoredBox(color: DealGoColors.amberSurface),
    );
    final Widget image = resolved == null || resolved.isEmpty
        ? placeholder
        : DealGoNetworkImage(
            resolved,
            fit: BoxFit.cover,
            fallback: placeholder,
          );
    return Stack(
      fit: StackFit.expand,
      children: [
        if (item.optionGroups.isEmpty || featured)
          image
        else
          DealGoHero(tag: foodItemHeroTag(item.id), child: image),
        if (!item.available)
          ColoredBox(
            color: Colors.white.withValues(alpha: 0.55),
            child: Center(
              child: FoodPill(
                label: l10n.foodItemSoldOut,
                foreground: DealGoColors.danger,
                background: DealGoColors.dangerSurface,
              ),
            ),
          ),
        if (photoCount > 1)
          Positioned(
            top: DealGoSpacing.s6,
            right: DealGoSpacing.s6,
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: DealGoColors.scrim,
                borderRadius: BorderRadius.circular(DealGoRadius.pill),
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: DealGoSpacing.s6,
                  vertical: DealGoSpacing.s2,
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      DealGoIcons.image,
                      size: 11,
                      color: Colors.white,
                    ),
                    const SizedBox(width: DealGoSpacing.s2),
                    Text(
                      '$photoCount',
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class _ItemMeta extends StatelessWidget {
  const _ItemMeta({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 12, color: DealGoColors.textTertiary),
        const SizedBox(width: 3),
        Text(
          label,
          style: Theme.of(context).textTheme.labelSmall
              ?.copyWith(color: DealGoColors.textSecondary),
        ),
      ],
    );
  }
}

/// Compact add / stepper: a 34pt circle instead of the default 48pt button so
/// the photo and price keep their room.
class _MenuAddControl extends StatelessWidget {
  const _MenuAddControl({
    required this.store,
    required this.item,
    this.compact = false,
    this.keyPrefix = 'food-add',
  });

  final FoodStoreDetail store;
  final FoodMenuItem item;
  final bool compact;
  final String keyPrefix;

  @override
  Widget build(BuildContext context) {
    final quantity = context.select<FoodCartCubit, int>((cart) {
      if (cart.state.storeId != store.id) {
        return 0;
      }
      var total = 0;
      for (final line in cart.state.lines) {
        if (line.placeItemId == item.id) {
          total += line.quantity;
        }
      }
      return total;
    });
    final l10n = AppLocalizations.of(context);
    final addSize = compact ? 30.0 : 34.0;
    if (quantity == 0) {
      if (item.optionGroups.isNotEmpty && !compact) {
        return SizedBox(
          height: 32,
          child: TextButton.icon(
            key: Key('$keyPrefix-${item.id}'),
            onPressed: () =>
                openFoodItemOptions(context: context, store: store, item: item),
            style: TextButton.styleFrom(
              foregroundColor: DealGoColors.primary,
              backgroundColor: DealGoColors.subtlePurple,
              padding: const EdgeInsets.symmetric(horizontal: DealGoSpacing.s8),
              minimumSize: const Size(0, 32),
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              shape: const StadiumBorder(),
            ),
            icon: const Icon(DealGoIcons.add, size: 15),
            label: Text(
              l10n.foodItemOptionsChoose,
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
            ),
          ),
        );
      }
      return Tooltip(
        message: item.optionGroups.isNotEmpty
            ? l10n.foodItemOptionsChoose
            : l10n.foodAddToCart,
        child: SizedBox(
          width: addSize,
          height: addSize,
          child: Material(
            color: DealGoColors.primary,
            shape: const CircleBorder(),
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              key: Key('$keyPrefix-${item.id}'),
              onTap: () =>
                  quickAddFoodItem(context: context, store: store, item: item),
              child: Icon(
                DealGoIcons.add,
                size: compact ? 18 : 20,
                color: Colors.white,
              ),
            ),
          ),
        ),
      );
    }
    final cart = context.read<FoodCartCubit>();
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _StepButton(
          icon: DealGoIcons.remove,
          tooltip: l10n.foodDecreaseQuantity,
          size: compact ? 26 : 30,
          onPressed: () => cart.adjustCatalogQuantity(item.id, -1),
        ),
        SizedBox(
          width: compact ? 20 : 24,
          child: Text(
            '$quantity',
            textAlign: TextAlign.center,
            style:
                (compact
                        ? Theme.of(context).textTheme.labelMedium
                        : Theme.of(context).textTheme.titleSmall)
                    ?.copyWith(fontWeight: FontWeight.w800),
          ),
        ),
        _StepButton(
          key: Key('$keyPrefix-${item.id}'),
          icon: DealGoIcons.add,
          tooltip: l10n.foodAddToCart,
          size: compact ? 26 : 30,
          onPressed: quantity >= foodLineQuantityMax
              ? null
              : () => quickAddFoodItem(
                  context: context,
                  store: store,
                  item: item,
                ),
        ),
      ],
    );
  }
}

class _StepButton extends StatelessWidget {
  const _StepButton({
    required this.icon,
    required this.tooltip,
    required this.onPressed,
    this.size = 30,
    super.key,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback? onPressed;
  final double size;

  @override
  Widget build(BuildContext context) {
    final enabled = onPressed != null;
    return Tooltip(
      message: tooltip,
      child: SizedBox(
        width: size,
        height: size,
        child: Material(
          color: enabled ? DealGoColors.primary : DealGoColors.divider,
          shape: const CircleBorder(),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: onPressed,
            child: Icon(
              icon,
              size: size < 30 ? 16 : 18,
              color: enabled ? Colors.white : DealGoColors.textSecondary,
            ),
          ),
        ),
      ),
    );
  }
}
