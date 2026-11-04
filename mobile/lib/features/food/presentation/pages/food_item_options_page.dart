import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/design_system/components/dealgo_primary_button.dart';
import '../../../../core/design_system/tokens/dealgo_tokens.dart';
import '../../../../core/motion/dealgo_motion_widgets.dart';
import '../../../../l10n/app_localizations.dart';
import '../../domain/entities/food_models.dart';
import '../../domain/entities/food_money.dart';
import '../cubit/food_cart_cubit.dart';
import '../food_categories_store.dart';
import '../utils/food_maps.dart';
import '../utils/food_routes.dart';
import '../widgets/food_cart_bar.dart';
import '../widgets/food_dish_gallery.dart';
import '../widgets/food_item_addons.dart';
import '../widgets/food_widgets.dart';
import '../widgets/food_badges.dart';
import '../widgets/food_category_tile.dart';
import '../../../../core/design_system/icons/dealgo_icons.dart';
import '../../../../core/design_system/components/dealgo_app_header.dart';

class FoodItemOptionsArgs {
  const FoodItemOptionsArgs({required this.store, required this.item});

  final FoodStoreDetail store;
  final FoodMenuItem item;
}

void openFoodItemOptions({
  required BuildContext context,
  required FoodStoreDetail store,
  required FoodMenuItem item,
}) {
  context.push(
    FoodRoutes.itemOptions(storeId: store.id, itemId: item.id),
    extra: FoodItemOptionsArgs(store: store, item: item),
  );
}

/// The row's plus button: one tap for a plain dish, options for a configured
/// one. Tapping the row itself always opens the detail page.
void quickAddFoodItem({
  required BuildContext context,
  required FoodStoreDetail store,
  required FoodMenuItem item,
}) {
  if (item.optionGroups.isNotEmpty) {
    openFoodItemOptions(context: context, store: store, item: item);
    return;
  }
  context.read<FoodCartCubit>().addItem(
    storeId: store.id,
    storeName: store.name,
    item: item,
    minOrderVnd: store.minOrderVnd,
    prepMinutes: store.estimatedPrepMinutes,
  );
}

/// C026 — full-page item options. Groups, bounds and surcharges come from the
/// store catalog (DEC-PROD-033); the server re-prices the choice at placement.
class FoodItemOptionsPage extends StatefulWidget {
  const FoodItemOptionsPage({required this.args, super.key});

  final FoodItemOptionsArgs args;

  @override
  State<FoodItemOptionsPage> createState() => _FoodItemOptionsPageState();
}

class _FoodItemOptionsPageState extends State<FoodItemOptionsPage> {
  final ScrollController _scroll = ScrollController();
  final Map<String, GlobalKey> _groupKeys = {};
  late List<FoodOptionGroup> _groups = widget.args.item.optionGroups;
  late FoodOptionSelection _selection = FoodOptionSelection.initial(_groups);
  var _quantity = 1;

  int get _unitPrice => widget.args.item.priceVnd + _selection.extrasVnd;

  int get _totalPrice => _unitPrice * _quantity;

  bool get _canAdd =>
      widget.args.item.available &&
      widget.args.store.canOrder &&
      _selection.isComplete;

  List<FoodOptionGroup> get _missingGroups => [
    for (final group in _groups)
      if (group.required && !_selection.satisfies(group)) group,
  ];

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  void _toggle(FoodOptionGroup group, FoodOptionChoice choice) {
    setState(() => _selection = _selection.toggle(group, choice));
  }

  void _scrollToMissing() {
    final missing = _missingGroups;
    if (missing.isEmpty) return;
    final target = _groupKeys[missing.first.id]?.currentContext;
    if (target == null) {
      if (_scroll.hasClients) {
        _scroll.animateTo(
          0,
          duration: const Duration(milliseconds: 280),
          curve: Curves.easeOutCubic,
        );
      }
      return;
    }
    Scrollable.ensureVisible(
      target,
      duration: const Duration(milliseconds: 280),
      curve: Curves.easeOutCubic,
      alignment: 0.05,
    );
  }

  void _add() {
    if (!_canAdd) {
      return;
    }
    final cart = context.read<FoodCartCubit>();
    final item = widget.args.item;
    if (_groups.isEmpty) {
      for (var i = 0; i < _quantity; i++) {
        cart.addItem(
          storeId: widget.args.store.id,
          storeName: widget.args.store.name,
          item: item,
          minOrderVnd: widget.args.store.minOrderVnd,
          prepMinutes: widget.args.store.estimatedPrepMinutes,
        );
      }
    } else {
      for (var i = 0; i < _quantity; i++) {
        cart.addConfiguredItem(
          storeId: widget.args.store.id,
          storeName: widget.args.store.name,
          lineId: _selection.lineId(item.id),
          name: [item.name, ..._selection.labels].join(' · '),
          unitPriceVnd: _unitPrice,
          catalogItemId: item.id,
          optionIds: _selection.optionIds,
          imageUrl: item.imageUrl,
          minOrderVnd: widget.args.store.minOrderVnd,
          prepMinutes: widget.args.store.estimatedPrepMinutes,
        );
      }
    }
    if (context.canPop()) {
      context.pop();
    }
  }

  Future<void> _openMaps(BuildContext context) async {
    final l10n = AppLocalizations.of(context);
    final opened = await openStoreInGoogleMaps(widget.args.store);
    if (opened || !context.mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(l10n.foodStoreMapOpenFailed)));
  }

  @override
  void didUpdateWidget(covariant FoodItemOptionsPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.args.item != widget.args.item) {
      _groups = widget.args.item.optionGroups;
      _selection = FoodOptionSelection.initial(_groups);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final textTheme = Theme.of(context).textTheme;
    final item = widget.args.item;
    final bestSeller = foodBestSellerIds(widget.args.store.items)
        .contains(item.id);
    return Scaffold(
      backgroundColor: DealGoColors.canvas,
      body: SafeArea(
        child: Column(
          children: [
            DealGoAppHeader(
              title: _groups.isEmpty
                  ? l10n.foodItemDetailTitle
                  : l10n.foodItemOptionsTitle,
            ),
            Expanded(
              child: ListView(
                controller: _scroll,
                padding: const EdgeInsets.fromLTRB(
                  DealGoDimensions.pageGutter,
                  0,
                  DealGoDimensions.pageGutter,
                  // The bar is a sibling below the list, never on top of it.
                  DealGoSpacing.s24,
                ),
                children: [
                  DealGoHero(
                    tag: foodItemHeroTag(item.id),
                    child: FoodDishGallery(
                      imageUrls: item.imageUrls,
                      fallbackImageUrl: item.imageUrl,
                      placeholderAsset: foodDishFallbackImage(
                        widget.args.store.category,
                        dishName: item.name,
                      ),
                    ),
                  ),
                  const SizedBox(height: DealGoSpacing.s16),
                  Container(
                    padding: const EdgeInsets.all(DealGoSpacing.s16),
                    decoration: BoxDecoration(
                      color: DealGoColors.card,
                      borderRadius: BorderRadius.circular(DealGoRadius.card),
                      boxShadow: DealGoShadows.card,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        InkWell(
                          key: const Key('food-item-store-link'),
                          onTap: () {
                            if (context.canPop()) context.pop();
                          },
                          child: Row(
                            children: [
                              Icon(
                                DealGoIcons.store,
                                size: 14,
                                color: DealGoColors.textSecondary,
                              ),
                              const SizedBox(width: DealGoSpacing.s4),
                              Expanded(
                                child: Text(
                                  l10n.foodItemInStore(widget.args.store.name),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: textTheme.labelSmall?.copyWith(
                                    color: DealGoColors.textSecondary,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                              Icon(
                                DealGoIcons.chevronRight,
                                size: 14,
                                color: DealGoColors.textTertiary,
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: DealGoSpacing.s8),
                        if (bestSeller) ...[
                          const FoodBestSellerBadge(),
                          const SizedBox(height: DealGoSpacing.s8),
                        ],
                        Text(item.name, style: textTheme.titleLarge),
                        if ((item.description ?? '').trim().isNotEmpty) ...[
                          const SizedBox(height: DealGoSpacing.s6),
                          Text(
                            item.description!.trim(),
                            style: textTheme.bodyMedium?.copyWith(
                              color: DealGoColors.textSecondary,
                            ),
                          ),
                        ],
                        const SizedBox(height: DealGoSpacing.s8),
                        _ItemMetaChips(store: widget.args.store, item: item),
                        const SizedBox(height: DealGoSpacing.s12),
                        Row(
                          children: [
                            Expanded(
                              child: FoodPriceText(
                                key: const Key('food-item-options-price'),
                                priceVnd: item.priceVnd,
                                originalPriceVnd: item.originalPriceVnd,
                                size: 20,
                              ),
                            ),
                            if (item.soldCount > 0)
                              Text(
                                l10n.merchantProductsSoldCount(
                                  '${item.soldCount}',
                                ),
                                style: textTheme.bodySmall,
                              ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: DealGoSpacing.s16),
                  if (!widget.args.store.canOrder) ...[
                    FoodNote(
                      key: const Key('food-item-store-closed'),
                      message:
                          widget.args.store.closedReason ==
                              StoreClosedReason.closed
                          ? l10n.foodStoreClosedBanner
                          : l10n.foodStorePausedBanner,
                      tone: FoodNoteTone.amber,
                    ),
                    const SizedBox(height: DealGoSpacing.s12),
                  ],
                  _QuantityPanel(
                    quantity: _quantity,
                    unitPriceVnd: _unitPrice,
                    onChanged: (value) => setState(() => _quantity = value),
                  ),
                  const SizedBox(height: DealGoSpacing.s12),
                  if (_groups.isEmpty)
                    _ItemInfoPanel(
                      store: widget.args.store,
                      item: item,
                      onOpenMaps: () => _openMaps(context),
                    )
                  else ...[
                    for (final group in _groups) ...[
                      KeyedSubtree(
                        key: _groupKeys.putIfAbsent(group.id, GlobalKey.new),
                        child: _OptionSection(
                          group: group,
                          selection: _selection,
                          missing: !_selection.satisfies(group),
                          onToggle: (choice) => _toggle(group, choice),
                          onSetQuantity: (choice, q) => setState(
                            () => _selection = _selection.setQuantity(
                              group,
                              choice,
                              q,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: DealGoSpacing.s12),
                    ],
                    _ItemInfoPanel(
                      store: widget.args.store,
                      item: item,
                      onOpenMaps: () => _openMaps(context),
                    ),
                  ],
                  FoodItemAddons(
                    store: widget.args.store,
                    excludeItemId: item.id,
                  ),
                ],
              ),
            ),
            DecoratedBox(
              decoration: BoxDecoration(
                color: DealGoColors.card,
                boxShadow: DealGoShadows.floating,
              ),
              child: SafeArea(
                top: false,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(
                    DealGoDimensions.pageGutter,
                    DealGoSpacing.s12,
                    DealGoDimensions.pageGutter,
                    DealGoSpacing.s12,
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // The cart of this store, one tap from checkout, kept as a
                      // quiet shortcut so the add button stays the only filled
                      // call to action on screen.
                      _CartShortcut(storeId: widget.args.store.id),
                      if (_selection.labels.isNotEmpty) ...[
                        const SizedBox(height: DealGoSpacing.s8),
                        Text(
                          l10n.foodItemSelectedOptions(
                            _selection.labels.join(', '),
                          ),
                          key: const Key('food-item-selected-options'),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: textTheme.bodySmall?.copyWith(
                            color: DealGoColors.textSecondary,
                          ),
                        ),
                      ],
                      if (_missingGroups.isNotEmpty) ...[
                        const SizedBox(height: DealGoSpacing.s8),
                        InkWell(
                          key: const Key('food-options-missing'),
                          onTap: _scrollToMissing,
                          borderRadius: BorderRadius.circular(
                            DealGoRadius.input,
                          ),
                          child: FoodNote(
                            message: l10n.foodItemOptionsMissingRequired(
                              _missingGroups.map((g) => g.title).join(', '),
                            ),
                            tone: FoodNoteTone.amber,
                          ),
                        ),
                      ],
                      Row(
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                l10n.foodItemOptionsTotal,
                                style: textTheme.bodySmall,
                              ),
                              Text(
                                formatVnd(_totalPrice),
                                key: const Key('food-item-options-total'),
                                style: textTheme.titleLarge?.copyWith(
                                  color: DealGoColors.primary,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(width: DealGoSpacing.s12),
                          Expanded(
                            child: DealGoPrimaryButton(
                              key: const Key('food-options-add'),
                              label: l10n.foodItemOptionsAdd,
                              trailingIcon: DealGoIcons.arrowRight,
                              enabled: _canAdd,
                              onPressed: _add,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

String _choicePriceLabel(AppLocalizations l10n, FoodOptionChoice choice) {
  if (!choice.available) return l10n.foodItemOptionsSoldOut;
  if (choice.extraVnd == 0) return l10n.foodItemOptionsFree;
  return '+${formatVnd(choice.extraVnd)}';
}

/// The store's current cart as a quiet row: the add button below it must be
/// the only filled control, so a second full-width bar is not an option.
class _CartShortcut extends StatelessWidget {
  const _CartShortcut({required this.storeId});

  final String storeId;

  @override
  Widget build(BuildContext context) {
    final cart = context.watch<FoodCartCubit>().state;
    if (!FoodCartBar.showsFor(cart, storeId: storeId)) {
      return const SizedBox.shrink();
    }
    final l10n = AppLocalizations.of(context);
    final textTheme = Theme.of(context).textTheme;
    final total = cart.subtotalVnd - cart.voucherDiscountVnd;
    return InkWell(
      key: const Key('food-cart-bar'),
      onTap: () => context.push(FoodRoutes.checkout),
      borderRadius: BorderRadius.circular(DealGoRadius.input),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: DealGoSpacing.s8),
        child: Row(
          children: [
            Icon(
              DealGoIcons.shoppingBag,
              size: 18,
              color: DealGoColors.primary,
            ),
            const SizedBox(width: DealGoSpacing.s8),
            Text(
              l10n.foodCartTitle,
              style: textTheme.labelLarge?.copyWith(
                color: DealGoColors.primary,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(width: DealGoSpacing.s8),
            Expanded(
              child: Text(
                '${l10n.checkoutItemCount(cart.itemCount)}'
                ' · ${formatVnd(total < 0 ? 0 : total)}',
                key: const Key('food-cart-bar-total'),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: textTheme.labelMedium?.copyWith(
                  color: DealGoColors.textSecondary,
                ),
              ),
            ),
            Text(
              l10n.foodViewCart,
              style: textTheme.labelMedium?.copyWith(
                color: DealGoColors.primary,
                fontWeight: FontWeight.w700,
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
    );
  }
}

class _ItemMetaChips extends StatelessWidget {
  const _ItemMetaChips({required this.store, required this.item});

  final FoodStoreDetail store;
  final FoodMenuItem item;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final category = foodCategoryLabel(context, store.category);
    final prep = item.prepMinutes ?? store.estimatedPrepMinutes;
    final chips = <Widget>[
      if (prep != null)
        FoodInfoChip(
          label: l10n.foodStorePrepChip(prep),
          icon: DealGoIcons.clock,
        ),
      if (item.soldCount > 0)
        FoodInfoChip(
          label: l10n.foodItemSold(item.soldCount),
          icon: DealGoIcons.trending,
        ),
      if (category != null)
        FoodInfoChip(label: category, icon: DealGoIcons.restaurant),
    ];
    if (chips.isEmpty) return const SizedBox.shrink();
    return Wrap(
      spacing: DealGoSpacing.s8,
      runSpacing: DealGoSpacing.s8,
      children: chips,
    );
  }
}

/// Merchant facts for the dish: category, prep time and where to pick it up.
class _ItemInfoPanel extends StatelessWidget {
  const _ItemInfoPanel({
    required this.store,
    required this.item,
    required this.onOpenMaps,
  });

  final FoodStoreDetail store;
  final FoodMenuItem item;
  final VoidCallback onOpenMaps;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final textTheme = Theme.of(context).textTheme;
    final category = foodCategoryLabel(context, store.category);
    final prep = item.prepMinutes ?? store.estimatedPrepMinutes;
    final address = store.addressLabel?.trim() ?? '';
    Widget row(IconData icon, String label, String value) => Padding(
      padding: const EdgeInsets.symmetric(vertical: DealGoSpacing.s4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 16, color: DealGoColors.textSecondary),
          const SizedBox(width: DealGoSpacing.s8),
          SizedBox(width: 92, child: Text(label, style: textTheme.bodySmall)),
          Expanded(child: Text(value, style: textTheme.bodyMedium)),
        ],
      ),
    );
    return FoodPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            l10n.foodItemInfoTitle,
            style: textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: DealGoSpacing.s8),
          row(DealGoIcons.store, l10n.foodStoreInfoName, store.name),
          if (category != null)
            row(DealGoIcons.restaurant, l10n.foodStoreInfoCategory, category),
          if (prep != null)
            row(
              DealGoIcons.timer,
              l10n.foodStoreInfoPrep,
              l10n.foodStorePrepChip(prep),
            ),
          row(
            DealGoIcons.pin,
            l10n.foodStoreInfoAddress,
            address.isEmpty ? l10n.foodStoreInfoAddressMissing : address,
          ),
          if (store.hasLocation || address.isNotEmpty) ...[
            const SizedBox(height: DealGoSpacing.s4),
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                key: const Key('food-item-directions'),
                onPressed: onOpenMaps,
                style: TextButton.styleFrom(
                  foregroundColor: DealGoColors.primary,
                  padding: const EdgeInsets.symmetric(
                    horizontal: DealGoSpacing.s8,
                  ),
                  visualDensity: VisualDensity.compact,
                ),
                icon: const Icon(DealGoIcons.navigation, size: 16),
                label: Text(l10n.foodStoreDirections),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _QuantityPanel extends StatelessWidget {
  const _QuantityPanel({
    required this.quantity,
    required this.unitPriceVnd,
    required this.onChanged,
  });

  final int quantity;
  final int unitPriceVnd;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final textTheme = Theme.of(context).textTheme;
    return FoodPanel(
      elevated: true,
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(l10n.foodItemQuantity, style: textTheme.titleMedium),
                Text(formatVnd(unitPriceVnd), style: textTheme.bodySmall),
              ],
            ),
          ),
          IconButton(
            key: const Key('food-item-qty-dec'),
            onPressed: quantity <= 1 ? null : () => onChanged(quantity - 1),
            icon: const Icon(DealGoIcons.remove),
          ),
          Text(
            '$quantity',
            key: const Key('food-item-qty'),
            style: textTheme.titleMedium,
          ),
          IconButton(
            key: const Key('food-item-qty-inc'),
            onPressed: quantity >= foodLineQuantityMax
                ? null
                : () => onChanged(quantity + 1),
            icon: const Icon(DealGoIcons.add),
          ),
        ],
      ),
    );
  }
}

class _OptionSection extends StatelessWidget {
  const _OptionSection({
    required this.group,
    required this.selection,
    required this.missing,
    required this.onToggle,
    required this.onSetQuantity,
  });

  final FoodOptionGroup group;
  final FoodOptionSelection selection;
  final bool missing;
  final ValueChanged<FoodOptionChoice> onToggle;
  final void Function(FoodOptionChoice choice, int quantity) onSetQuantity;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final l10n = AppLocalizations.of(context);
    final anyQty = group.choices.any((c) => c.maxQuantity > 1);
    final chipStyle = !group.multi && !anyQty && group.choices.length <= 4;
    final sideBySide = chipStyle && group.choices.length <= 2;
    return FoodPanel(
      elevated: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  group.title,
                  style: textTheme.titleMedium?.copyWith(
                    color: missing ? DealGoColors.danger : null,
                  ),
                ),
              ),
              Text(
                [
                  group.required
                      ? l10n.foodItemOptionsRequired
                      : l10n.foodItemOptionsOptional,
                  if (group.multi) l10n.foodItemOptionsUpTo(group.maxSelect),
                ].join(' · '),
                style: textTheme.labelSmall?.copyWith(
                  color: missing
                      ? DealGoColors.danger
                      : DealGoColors.textSecondary,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          if (missing) ...[
            const SizedBox(height: DealGoSpacing.s4),
            Text(
              group.multi
                  ? l10n.foodItemOptionsUpTo(group.maxSelect)
                  : l10n.foodItemOptionsChooseRequired,
              style: textTheme.labelSmall?.copyWith(color: DealGoColors.danger),
            ),
          ],
          const SizedBox(height: DealGoSpacing.s12),
          if (chipStyle)
            sideBySide
                ? Row(
                    children: [
                      for (var i = 0; i < group.choices.length; i++) ...[
                        if (i > 0) const SizedBox(width: DealGoSpacing.s8),
                        Expanded(
                          child: _ChoiceTile(
                            key: Key('food-option-${group.choices[i].id}'),
                            label: group.choices[i].label,
                            extra: _choicePriceLabel(l10n, group.choices[i]),
                            selected:
                                selection.quantityOf(
                                  group.id,
                                  group.choices[i].id,
                                ) >
                                0,
                            onTap: group.choices[i].available
                                ? () => onToggle(group.choices[i])
                                : null,
                            expanded: true,
                          ),
                        ),
                      ],
                    ],
                  )
                : Wrap(
                    spacing: DealGoSpacing.s8,
                    runSpacing: DealGoSpacing.s8,
                    children: [
                      for (final choice in group.choices)
                        _ChoiceTile(
                          key: Key('food-option-${choice.id}'),
                          label: choice.label,
                          extra: _choicePriceLabel(l10n, choice),
                          selected:
                              selection.quantityOf(group.id, choice.id) > 0,
                          onTap: choice.available
                              ? () => onToggle(choice)
                              : null,
                        ),
                    ],
                  )
          else
            for (final choice in group.choices) ...[
              if (choice.maxQuantity > 1)
                _QtyOptionRow(
                  key: Key('food-option-${choice.id}'),
                  choice: choice,
                  quantity: selection.quantityOf(group.id, choice.id),
                  onSetQuantity: (q) => onSetQuantity(choice, q),
                )
              else
                InkWell(
                  key: Key('food-option-${choice.id}'),
                  onTap: choice.available ? () => onToggle(choice) : null,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      vertical: DealGoSpacing.s8,
                    ),
                    child: Row(
                      children: [
                        Icon(
                          selection.quantityOf(group.id, choice.id) > 0
                              ? DealGoIcons.radioOn
                              : DealGoIcons.radioOff,
                          color: selection.quantityOf(group.id, choice.id) > 0
                              ? DealGoColors.primary
                              : DealGoColors.textSecondary,
                        ),
                        const SizedBox(width: DealGoSpacing.s12),
                        Expanded(
                          child: Text(
                            choice.label,
                            style: choice.available
                                ? null
                                : TextStyle(color: DealGoColors.textSecondary),
                          ),
                        ),
                        Text(
                          _choicePriceLabel(l10n, choice),
                          style: textTheme.bodyMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
        ],
      ),
    );
  }
}

class _QtyOptionRow extends StatelessWidget {
  const _QtyOptionRow({
    super.key,
    required this.choice,
    required this.quantity,
    required this.onSetQuantity,
  });

  final FoodOptionChoice choice;
  final int quantity;
  final ValueChanged<int> onSetQuantity;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final l10n = AppLocalizations.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: DealGoSpacing.s8),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  choice.label,
                  style: choice.available
                      ? null
                      : TextStyle(color: DealGoColors.textSecondary),
                ),
                Text(
                  _choicePriceLabel(l10n, choice),
                  style: textTheme.bodySmall,
                ),
              ],
            ),
          ),
          IconButton(
            key: Key('food-option-qty-dec-${choice.id}'),
            onPressed: !choice.available || quantity <= 0
                ? null
                : () => onSetQuantity(quantity - 1),
            icon: const Icon(Icons.remove_circle_outline),
          ),
          Text(
            '$quantity',
            key: Key('food-option-qty-${choice.id}'),
            style: textTheme.titleMedium,
          ),
          IconButton(
            key: Key('food-option-qty-inc-${choice.id}'),
            onPressed: !choice.available || quantity >= choice.maxQuantity
                ? null
                : () => onSetQuantity(quantity + 1),
            icon: const Icon(Icons.add_circle_outline),
          ),
        ],
      ),
    );
  }
}

class _ChoiceTile extends StatelessWidget {
  const _ChoiceTile({
    required this.label,
    required this.extra,
    required this.selected,
    required this.onTap,
    this.expanded = false,
    super.key,
  });

  final String label;
  final String extra;
  final bool selected;
  final bool expanded;

  /// Null when the choice is sold out.
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final body = Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: DealGoSpacing.s12,
        vertical: DealGoSpacing.s12,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: textTheme.bodyMedium?.copyWith(
              color: onTap == null
                  ? DealGoColors.textSecondary
                  : selected
                  ? DealGoColors.primary
                  : DealGoColors.text,
              fontWeight: FontWeight.w700,
            ),
          ),
          Text(
            extra,
            style: textTheme.bodySmall?.copyWith(
              color: selected
                  ? DealGoColors.primary
                  : DealGoColors.textSecondary,
            ),
          ),
        ],
      ),
    );
    return Material(
      color: selected ? DealGoColors.subtlePurple : DealGoColors.card,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(DealGoRadius.input),
        side: BorderSide(
          color: selected ? DealGoColors.primary : DealGoColors.border,
          width: selected ? 1.6 : 1,
        ),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(DealGoRadius.input),
        child: expanded ? body : SizedBox(width: 140, child: body),
      ),
    );
  }
}
