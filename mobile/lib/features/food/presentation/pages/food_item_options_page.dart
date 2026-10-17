import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/design_system/components/dealgo_primary_button.dart';
import '../../../../core/design_system/tokens/dealgo_tokens.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../identity/presentation/widgets/auth_widgets.dart';
import '../../domain/entities/food_models.dart';
import '../../domain/entities/food_money.dart';
import '../cubit/food_cart_cubit.dart';
import '../utils/food_routes.dart';
import '../widgets/food_widgets.dart';
import 'food_item_options_sheet.dart';

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
  final groups = foodOptionGroupsForItem(item.id);
  if (groups.isEmpty) {
    context.read<FoodCartCubit>().addItem(
      storeId: store.id,
      storeName: store.name,
      item: item,
    );
    return;
  }
  context.push(
    FoodRoutes.itemOptions(storeId: store.id, itemId: item.id),
    extra: FoodItemOptionsArgs(store: store, item: item),
  );
}

/// C026 — full-page item options (preferred over thin sheet).
class FoodItemOptionsPage extends StatefulWidget {
  const FoodItemOptionsPage({required this.args, super.key});

  final FoodItemOptionsArgs args;

  @override
  State<FoodItemOptionsPage> createState() => _FoodItemOptionsPageState();
}

class _FoodItemOptionsPageState extends State<FoodItemOptionsPage> {
  late final List<FoodOptionGroup> _groups = foodOptionGroupsForItem(
    widget.args.item.id,
  );
  late final Map<String, Set<String>> _selected = {
    for (final group in _groups)
      group.id: {
        if (group.required && group.choices.isNotEmpty) group.choices.first.id,
      },
  };

  int get _extras {
    var total = 0;
    for (final group in _groups) {
      final picked = _selected[group.id] ?? const <String>{};
      for (final choice in group.choices) {
        if (picked.contains(choice.id)) {
          total += choice.extraVnd;
        }
      }
    }
    return total;
  }

  int get _unitPrice => widget.args.item.priceVnd + _extras;

  String get _displayName {
    final parts = <String>[widget.args.item.name];
    for (final group in _groups) {
      final picked = _selected[group.id] ?? const <String>{};
      for (final choice in group.choices) {
        if (picked.contains(choice.id) &&
            !(group.required &&
                choice == group.choices.first &&
                choice.extraVnd == 0)) {
          parts.add(choice.label);
        }
      }
    }
    return parts.join(' · ');
  }

  String get _lineId {
    final tokens = <String>[widget.args.item.id];
    for (final group in _groups) {
      final picked = [...(_selected[group.id] ?? const <String>{})]..sort();
      tokens.add('${group.id}:${picked.join('+')}');
    }
    return tokens.join('|');
  }

  bool get _canAdd {
    for (final group in _groups) {
      if (group.required && (_selected[group.id]?.isEmpty ?? true)) {
        return false;
      }
    }
    return widget.args.item.available;
  }

  void _toggle(FoodOptionGroup group, FoodOptionChoice choice) {
    setState(() {
      final current = {...(_selected[group.id] ?? <String>{})};
      if (group.multi) {
        if (current.contains(choice.id)) {
          current.remove(choice.id);
        } else {
          current.add(choice.id);
        }
      } else {
        current
          ..clear()
          ..add(choice.id);
      }
      _selected[group.id] = current;
    });
  }

  void _add() {
    if (!_canAdd) {
      return;
    }
    context.read<FoodCartCubit>().addConfiguredItem(
      storeId: widget.args.store.id,
      storeName: widget.args.store.name,
      lineId: _lineId,
      name: _displayName,
      unitPriceVnd: _unitPrice,
      catalogItemId: widget.args.item.id,
    );
    if (context.canPop()) {
      context.pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final textTheme = Theme.of(context).textTheme;
    final item = widget.args.item;
    return Scaffold(
      backgroundColor: DealGoColors.canvas,
      body: SafeArea(
        child: Column(
          children: [
            FoodScreenHeader(
              title: l10n.foodItemOptionsTitle,
              trailing: const DealGoWordmark(),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(
                  DealGoDimensions.pageGutter,
                  0,
                  DealGoDimensions.pageGutter,
                  DealGoSpacing.s16,
                ),
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(DealGoRadius.card),
                    child: Image.asset(
                      'assets/images/food_bun_bo_special.png',
                      height: 180,
                      width: double.infinity,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stack) {
                        return const ColoredBox(
                          color: Color(0xFFFFF4EA),
                          child: SizedBox(
                            height: 180,
                            child: Icon(
                              Icons.ramen_dining,
                              color: Color(0xFFEA580C),
                              size: 64,
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: DealGoSpacing.s16),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Text(item.name, style: textTheme.titleLarge),
                      ),
                      Text(
                        formatVnd(item.priceVnd),
                        style: textTheme.titleMedium?.copyWith(
                          color: DealGoColors.primary,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: DealGoSpacing.s4),
                  Text(
                    l10n.foodItemOptionsRating,
                    style: textTheme.bodySmall?.copyWith(
                      color: DealGoColors.amber,
                    ),
                  ),
                  const SizedBox(height: DealGoSpacing.s8),
                  Text(
                    l10n.foodItemOptionsDescription,
                    style: textTheme.bodySmall,
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
                        selected: _selected[group.id] ?? const {},
                        onToggle: (choice) => _toggle(group, choice),
                      ),
                      const SizedBox(height: DealGoSpacing.s12),
                    ],
                ],
              ),
            ),
            DecoratedBox(
              decoration: const BoxDecoration(
                color: DealGoColors.card,
                border: Border(top: BorderSide(color: DealGoColors.border)),
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
                  child: Row(
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
                            style: textTheme.titleMedium?.copyWith(
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
                          trailingIcon: Icons.arrow_forward,
                          enabled: _canAdd,
                          onPressed: _add,
                        ),
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
    required this.selected,
    required this.onToggle,
  });

  final FoodOptionGroup group;
  final Set<String> selected;
  final ValueChanged<FoodOptionChoice> onToggle;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final l10n = AppLocalizations.of(context);
    return DecoratedBox(
      decoration: BoxDecoration(
        color: DealGoColors.card,
        borderRadius: BorderRadius.circular(DealGoRadius.card),
        border: Border.all(color: DealGoColors.border),
      ),
      child: Padding(
        padding: const EdgeInsets.all(DealGoSpacing.s16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(group.title, style: textTheme.titleMedium),
                ),
                Text(
                  group.required
                      ? l10n.foodItemOptionsRequired
                      : l10n.foodItemOptionsOptional,
                  style: textTheme.labelSmall?.copyWith(
                    color: group.required
                        ? DealGoColors.primary
                        : DealGoColors.textSecondary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
            const SizedBox(height: DealGoSpacing.s12),
            if (!group.multi &&
                group.choices.length <= 4 &&
                group.id != 'topping')
              Wrap(
                spacing: DealGoSpacing.s8,
                runSpacing: DealGoSpacing.s8,
                children: [
                  for (final choice in group.choices)
                    _ChoiceTile(
                      label: choice.label,
                      extra: choice.extraVnd == 0
                          ? '+ 0đ'
                          : '+${formatVnd(choice.extraVnd)}',
                      selected: selected.contains(choice.id),
                      onTap: () => onToggle(choice),
                    ),
                ],
              )
            else
              for (final choice in group.choices) ...[
                InkWell(
                  onTap: () => onToggle(choice),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      vertical: DealGoSpacing.s8,
                    ),
                    child: Row(
                      children: [
                        Icon(
                          selected.contains(choice.id)
                              ? Icons.radio_button_checked
                              : Icons.radio_button_off,
                          color: selected.contains(choice.id)
                              ? DealGoColors.primary
                              : DealGoColors.textSecondary,
                        ),
                        const SizedBox(width: DealGoSpacing.s12),
                        Expanded(child: Text(choice.label)),
                        Text(
                          choice.extraVnd == 0
                              ? '+ 0đ'
                              : '+${formatVnd(choice.extraVnd)}',
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
  });

  final String label;
  final String extra;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Material(
      color: selected ? DealGoColors.subtlePurple : DealGoColors.card,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(DealGoRadius.input),
        side: BorderSide(
          color: selected ? DealGoColors.primary : DealGoColors.border,
          width: selected ? 1.4 : 1,
        ),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(DealGoRadius.input),
        child: SizedBox(
          width: 140,
          child: Padding(
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
                    color: selected ? DealGoColors.primary : DealGoColors.text,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                Text(
                  extra,
                  style: textTheme.bodySmall?.copyWith(
                    color: DealGoColors.textSecondary,
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
