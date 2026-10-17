import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/config/app_env.dart';
import '../../../../core/mock/food_option_groups.dart';
import '../../../../core/motion/dealgo_sheet.dart';
import '../../../../core/design_system/components/dealgo_primary_button.dart';
import '../../../../core/design_system/tokens/dealgo_tokens.dart';
import '../../domain/entities/food_models.dart';
import '../../domain/entities/food_money.dart';
import '../cubit/food_cart_cubit.dart';

export '../../../../core/mock/food_option_groups.dart'
    show FoodOptionChoice, FoodOptionGroup, mockFoodOptionGroups;

List<FoodOptionGroup> foodOptionGroupsForItem(String itemId) {
  if (!useMockData) {
    return const [];
  }
  return mockFoodOptionGroups(itemId);
}

Future<void> showFoodItemOptionsSheet({
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
    return Future.value();
  }
  return showDealGoSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: DealGoColors.canvas,
    builder: (sheetContext) {
      return BlocProvider.value(
        value: context.read<FoodCartCubit>(),
        child: _FoodItemOptionsSheet(store: store, item: item, groups: groups),
      );
    },
  );
}

class _FoodItemOptionsSheet extends StatefulWidget {
  const _FoodItemOptionsSheet({
    required this.store,
    required this.item,
    required this.groups,
  });

  final FoodStoreDetail store;
  final FoodMenuItem item;
  final List<FoodOptionGroup> groups;

  @override
  State<_FoodItemOptionsSheet> createState() => _FoodItemOptionsSheetState();
}

class _FoodItemOptionsSheetState extends State<_FoodItemOptionsSheet> {
  late final Map<String, Set<String>> _selected = {
    for (final group in widget.groups)
      group.id: {
        if (group.required && group.choices.isNotEmpty) group.choices.first.id,
      },
  };

  int get _extras {
    var total = 0;
    for (final group in widget.groups) {
      final picked = _selected[group.id] ?? const <String>{};
      for (final choice in group.choices) {
        if (picked.contains(choice.id)) {
          total += choice.extraVnd;
        }
      }
    }
    return total;
  }

  int get _unitPrice => widget.item.priceVnd + _extras;

  String get _displayName {
    final parts = <String>[widget.item.name];
    for (final group in widget.groups) {
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
    final tokens = <String>[widget.item.id];
    for (final group in widget.groups) {
      final picked = [...(_selected[group.id] ?? const <String>{})]..sort();
      tokens.add('${group.id}:${picked.join('+')}');
    }
    return tokens.join('|');
  }

  bool get _canAdd {
    for (final group in widget.groups) {
      if (group.required && (_selected[group.id]?.isEmpty ?? true)) {
        return false;
      }
    }
    return widget.item.available;
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
      storeId: widget.store.id,
      storeName: widget.store.name,
      lineId: _lineId,
      name: _displayName,
      unitPriceVnd: _unitPrice,
      catalogItemId: widget.item.id,
    );
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final height = MediaQuery.sizeOf(context).height * 0.92;
    return SizedBox(
      height: height,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(
              DealGoDimensions.pageGutter,
              DealGoSpacing.s12,
              DealGoDimensions.pageGutter,
              DealGoSpacing.s8,
            ),
            child: Row(
              children: [
                IconButton(
                  tooltip: 'Đóng',
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.close),
                ),
                Expanded(
                  child: Text(
                    'Tùy chọn món ăn',
                    textAlign: TextAlign.center,
                    style: textTheme.titleMedium,
                  ),
                ),
                const SizedBox(width: DealGoDimensions.minTapTarget),
              ],
            ),
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
                    height: 160,
                    width: double.infinity,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stack) {
                      return const ColoredBox(
                        color: Color(0xFFFFF4EA),
                        child: SizedBox(
                          height: 160,
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
                Text(widget.item.name, style: textTheme.titleLarge),
                const SizedBox(height: DealGoSpacing.s4),
                Text(
                  formatVnd(widget.item.priceVnd),
                  style: textTheme.titleMedium?.copyWith(
                    color: DealGoColors.primary,
                  ),
                ),
                const SizedBox(height: DealGoSpacing.s4),
                Text(
                  '★ 4.8 (320 đánh giá) · Đã bán 2,4k',
                  style: textTheme.bodySmall?.copyWith(
                    color: DealGoColors.amber,
                  ),
                ),
                const SizedBox(height: DealGoSpacing.s8),
                Text(
                  'Bún bò nước dùng đậm đà, thịt mềm, chả cua và rau thơm.',
                  style: textTheme.bodySmall,
                ),
                const SizedBox(height: DealGoSpacing.s16),
                for (final group in widget.groups) ...[
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
                        Text('Tổng cộng', style: textTheme.bodySmall),
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
                        label: 'Thêm vào giỏ hàng',
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
                  group.required ? 'Bắt buộc' : 'Tùy chọn',
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
                    _ChoiceChip(
                      label: choice.extraVnd == 0
                          ? choice.label
                          : '${choice.label} +${formatVnd(choice.extraVnd)}',
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
                              ? '0đ'
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

class _ChoiceChip extends StatelessWidget {
  const _ChoiceChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
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
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: DealGoSpacing.s12,
            vertical: DealGoSpacing.s12,
          ),
          child: Text(
            label,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: selected ? DealGoColors.primary : DealGoColors.text,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ),
    );
  }
}
