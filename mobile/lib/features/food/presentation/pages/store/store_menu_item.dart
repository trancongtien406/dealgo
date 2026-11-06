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

/// One dish row: square photo on the left, name/description/specs/price on the
/// right, with the add control pinned to the price line.
class _MenuItem extends StatelessWidget {
  const _MenuItem({
    required this.store,
    required this.item,
    this.featured = false,
    this.compact = false,
    super.key,
  });

  final FoodStoreDetail store;
  final FoodMenuItem item;

  /// Copy in the best-sellers group: its own add key and no hero flight.
  final bool featured;

  /// Narrow row beside the category rail: smaller photo, type and controls.
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final l10n = AppLocalizations.of(context);
    final description = item.description?.trim();
    final closed = !store.canOrder;
    final photoSize = compact ? _menuCompactImageWidth : _menuImageWidth;
    final inset = compact ? DealGoSpacing.s8 : DealGoSpacing.s12;
    final prepMinutes = item.prepMinutes ?? store.estimatedPrepMinutes;
    // One line under the description: what the buyer weighs before tapping.
    // The best-seller mark lives on the section, repeating it in every row
    // only eats the width the numbers need.
    final meta = [
      if (item.soldCount > 0) l10n.foodItemSold(item.soldCount),
      if (prepMinutes != null) l10n.foodStorePrepShort(prepMinutes),
    ];
    return Material(
      color: DealGoColors.card,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(DealGoRadius.button),
        side: BorderSide(color: DealGoColors.divider),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        key: Key('food-dish-${item.id}'),
        onTap: item.available
            ? () {
                if (closed) {
                  _showClosedHint(context, store);
                  return;
                }
                openFoodItemOptions(context: context, store: store, item: item);
              }
            : null,
        child: Padding(
          padding: EdgeInsets.all(inset),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _photo(context, l10n, photoSize),
              SizedBox(width: compact ? DealGoSpacing.s8 : DealGoSpacing.s12),
              Expanded(
                child: ConstrainedBox(
                  constraints: BoxConstraints(minHeight: photoSize),
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
                              fontSize: compact ? 14.5 : 15.5,
                              height: 1.3,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          if (description != null &&
                              description.isNotEmpty) ...[
                            const SizedBox(height: DealGoSpacing.s2),
                            Text(
                              description,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: textTheme.bodySmall?.copyWith(
                                color: DealGoColors.textSecondary,
                                height: 1.35,
                              ),
                            ),
                          ],
                          if (meta.isNotEmpty) ...[
                            const SizedBox(height: DealGoSpacing.s6),
                            Text(
                              meta.join(' · '),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: textTheme.labelSmall?.copyWith(
                                color: DealGoColors.textTertiary,
                              ),
                            ),
                          ],
                        ],
                      ),
                      Padding(
                        padding: const EdgeInsets.only(top: DealGoSpacing.s8),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            Expanded(
                              child: FoodPriceText(
                                key: Key('food-price-${item.id}'),
                                priceVnd: item.priceVnd,
                                originalPriceVnd: item.originalPriceVnd,
                                showPercent: false,
                                size: compact ? 16 : 17,
                              ),
                            ),
                            const SizedBox(width: DealGoSpacing.s4),
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
            ],
          ),
        ),
      ),
    );
  }

  /// Square dish photo with the discount sticker, gallery count and the
  /// sold-out veil; only items that open the options page fly it.
  Widget _photo(BuildContext context, AppLocalizations l10n, double size) {
    final resolved = resolveMediaUrl(item.imageUrl);
    final photoCount = foodDishGalleryImages(
      imageUrls: item.imageUrls,
      fallbackImageUrl: item.imageUrl,
    ).length;
    final placeholder = Container(
      width: size,
      height: size,
      color: DealGoColors.amberSurface,
      child: Center(
        child: Icon(
          DealGoIcons.restaurant,
          size: size * 0.45,
          color: DealGoColors.amber,
        ),
      ),
    );
    final Widget image = resolved == null || resolved.isEmpty
        ? placeholder
        : DealGoNetworkImage(
            resolved,
            fit: BoxFit.cover,
            fallback: placeholder,
          );
    final discount = item.discountPercent;
    return SizedBox(
      key: Key('food-menu-photo-${item.id}'),
      width: size,
      height: size,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(DealGoRadius.input),
        child: Stack(
          fit: StackFit.expand,
          children: [
            if (item.optionGroups.isEmpty || featured)
              image
            else
              DealGoHero(tag: foodItemHeroTag(item.id), child: image),
            if (discount > 0)
              Positioned(
                left: DealGoSpacing.s4,
                bottom: DealGoSpacing.s4,
                child: FoodDiscountPill(percent: discount),
              ),
            if (photoCount > 1)
              Positioned(
                top: DealGoSpacing.s4,
                right: DealGoSpacing.s4,
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
                          style: Theme.of(context).textTheme.labelSmall
                              ?.copyWith(
                                color: Colors.white,
                                fontWeight: FontWeight.w700,
                              ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
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
          ],
        ),
      ),
    );
  }
}

/// Compact add / stepper: a 30pt rounded square instead of the default 48pt
/// button so the photo and the price keep their room.
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
    final addSize = compact ? 30.0 : 32.0;
    // Required groups without a default pick cannot be priced by a quick add,
    // so only those rows still route through the options page.
    final needsOptions =
        item.optionGroups.isNotEmpty &&
        !FoodOptionSelection.initial(item.optionGroups).isComplete;
    if (quantity == 0) {
      if (needsOptions && !compact) {
        return SizedBox(
          height: 30,
          child: TextButton.icon(
            key: Key('$keyPrefix-${item.id}'),
            onPressed: () =>
                openFoodItemOptions(context: context, store: store, item: item),
            style: TextButton.styleFrom(
              foregroundColor: DealGoColors.primary,
              backgroundColor: DealGoColors.subtlePurple,
              padding: const EdgeInsets.symmetric(horizontal: DealGoSpacing.s8),
              minimumSize: const Size(0, 30),
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              shape: const StadiumBorder(),
            ),
            icon: const Icon(DealGoIcons.add, size: 14),
            label: Text(
              l10n.foodItemOptionsChoose,
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
            ),
          ),
        );
      }
      return Tooltip(
        message: needsOptions ? l10n.foodItemOptionsChoose : l10n.foodAddToCart,
        child: SizedBox(
          width: addSize,
          height: addSize,
          child: Material(
            color: DealGoColors.primary,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(DealGoRadius.small),
            ),
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
          width: compact ? 22 : 26,
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
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(DealGoRadius.small),
          ),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: onPressed,
            child: Icon(
              icon,
              size: size < 28 ? 15 : 17,
              color: enabled ? Colors.white : DealGoColors.textSecondary,
            ),
          ),
        ),
      ),
    );
  }
}
