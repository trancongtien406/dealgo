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
import '../utils/food_routes.dart';
import '../widgets/food_cart_bar.dart';
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
  if (item.optionGroups.isEmpty) {
    context.read<FoodCartCubit>().addItem(
      storeId: store.id,
      storeName: store.name,
      item: item,
      minOrderVnd: store.minOrderVnd,
      prepMinutes: store.estimatedPrepMinutes,
    );
    return;
  }
  context.push(
    FoodRoutes.itemOptions(storeId: store.id, itemId: item.id),
    extra: FoodItemOptionsArgs(store: store, item: item),
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
  late List<FoodOptionGroup> _groups = widget.args.item.optionGroups;
  late FoodOptionSelection _selection = FoodOptionSelection.initial(_groups);

  int get _unitPrice => widget.args.item.priceVnd + _selection.extrasVnd;

  bool get _canAdd => widget.args.item.available && _selection.isComplete;

  void _toggle(FoodOptionGroup group, FoodOptionChoice choice) {
    setState(() => _selection = _selection.toggle(group, choice));
  }

  void _add() {
    if (!_canAdd) {
      return;
    }
    final item = widget.args.item;
    context.read<FoodCartCubit>().addConfiguredItem(
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
    if (context.canPop()) {
      context.pop();
    }
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
            DealGoAppHeader(title: l10n.foodItemOptionsTitle),
            Expanded(
              child: ListView(
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
                    child: FoodCoverImage(
                      imageUrl: item.imageUrl,
                      aspectRatio: 4 / 3,
                      placeholderAsset: foodDishFallbackImage(
                        widget.args.store.category,
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
                        if (item.isNew || bestSeller) ...[
                          FoodItemBadges(
                            isNew: item.isNew,
                            bestSeller: bestSeller,
                          ),
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
                  if (_groups.isEmpty)
                    FoodNote(
                      message: l10n.foodItemOptionsNoGroups,
                      tone: FoodNoteTone.amber,
                    )
                  else
                    for (final group in _groups) ...[
                      _OptionSection(
                        group: group,
                        selection: _selection,
                        onToggle: (choice) => _toggle(group, choice),
                        onSetQuantity: (choice, q) => setState(
                          () => _selection = _selection.setQuantity(
                            group,
                            choice,
                            q,
                          ),
                        ),
                      ),
                      const SizedBox(height: DealGoSpacing.s12),
                    ],
                ],
              ),
            ),
            DecoratedBox(
              decoration: const BoxDecoration(
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
                      // What is already in the cart, one tap from checkout.
                      FoodCartBar(
                        storeId: widget.args.store.id,
                        offers: widget.args.store.offers,
                        inline: true,
                      ),
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
                                formatVnd(_unitPrice),
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

class _OptionSection extends StatelessWidget {
  const _OptionSection({
    required this.group,
    required this.selection,
    required this.onToggle,
    required this.onSetQuantity,
  });

  final FoodOptionGroup group;
  final FoodOptionSelection selection;
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
              Expanded(child: Text(group.title, style: textTheme.titleMedium)),
              Text(
                [
                  group.required
                      ? l10n.foodItemOptionsRequired
                      : l10n.foodItemOptionsOptional,
                  if (group.multi) l10n.foodItemOptionsUpTo(group.maxSelect),
                ].join(' · '),
                style: textTheme.labelSmall?.copyWith(
                  color: DealGoColors.textSecondary,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
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
                            extra: group.choices[i].available
                                ? '+${formatVnd(group.choices[i].extraVnd)}'
                                : l10n.foodItemOptionsSoldOut,
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
                          extra: choice.available
                              ? '+${formatVnd(choice.extraVnd)}'
                              : l10n.foodItemOptionsSoldOut,
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
                                : const TextStyle(
                                    color: DealGoColors.textSecondary,
                                  ),
                          ),
                        ),
                        Text(
                          choice.available
                              ? '+${formatVnd(choice.extraVnd)}'
                              : l10n.foodItemOptionsSoldOut,
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
                      : const TextStyle(color: DealGoColors.textSecondary),
                ),
                Text(
                  choice.available
                      ? '+${formatVnd(choice.extraVnd)}'
                      : l10n.foodItemOptionsSoldOut,
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
