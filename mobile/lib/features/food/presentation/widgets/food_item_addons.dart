import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/design_system/icons/dealgo_icons.dart';
import '../../../../core/design_system/tokens/dealgo_tokens.dart';
import '../../../../core/design_system/tokens/dealgo_type_scale.dart';
import '../../../../l10n/app_localizations.dart';
import '../../domain/entities/food_models.dart';
import '../../domain/entities/food_money.dart';
import '../../domain/repositories/food_repository.dart';
import '../cubit/food_cart_cubit.dart';
import 'food_widgets.dart';

/// Server cap for `GET /v1/food/stores/:id/suggestions`.
const int foodItemAddonsMax = 6;

const double _tileHeight = 96;
const double _tileWidth = 224;
const double _tileInset = DealGoSpacing.s8;
const double _thumbSize = 56;
const double _addSize = 48;

/// "Món ăn kèm": up to six dishes from another menu category of the same
/// store, one tap each to add a plain unit.
///
/// Hidden until two suggestions arrive and after any load failure, so a
/// suggestion read never blocks adding the dish being configured.
class FoodItemAddons extends StatefulWidget {
  const FoodItemAddons({
    required this.store,
    required this.excludeItemId,
    super.key,
  });

  final FoodStoreDetail store;

  /// The dish being configured; never suggested back to itself.
  final String excludeItemId;

  @override
  State<FoodItemAddons> createState() => _FoodItemAddonsState();
}

class _FoodItemAddonsState extends State<FoodItemAddons> {
  List<FoodFeaturedItem> _items = const [];

  /// Bumped on every load so a slow reply for a superseded dish is dropped
  /// instead of repainting the strip for the dish that replaced it.
  var _generation = 0;

  @override
  void initState() {
    super.initState();
    unawaited(_load());
  }

  @override
  void didUpdateWidget(covariant FoodItemAddons oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.excludeItemId != widget.excludeItemId ||
        oldWidget.store.id != widget.store.id) {
      _items = const [];
      unawaited(_load());
    }
  }

  Future<void> _load() async {
    final generation = ++_generation;
    try {
      final token = currentAccessToken(context);
      if (token == null) {
        return;
      }
      final repository = context.read<FoodRepository>();
      final suggestions = await repository.listStoreSuggestions(
        token,
        widget.store.id,
        exclude: [widget.excludeItemId],
      );
      if (!mounted || generation != _generation) {
        return;
      }
      setState(() {
        _items = suggestions.take(foodItemAddonsMax).toList(growable: false);
      });
    } on Object {
      if (!mounted || generation != _generation) {
        return;
      }
      setState(() => _items = const []);
    }
  }

  void _add(FoodFeaturedItem suggestion) {
    context.read<FoodCartCubit>().addItem(
      storeId: widget.store.id,
      storeName: widget.store.name,
      item: FoodMenuItem(
        id: suggestion.id,
        name: suggestion.name,
        priceVnd: suggestion.priceVnd,
        available: true,
        imageUrl: suggestion.imageUrl,
      ),
      minOrderVnd: widget.store.minOrderVnd,
      prepMinutes: widget.store.estimatedPrepMinutes,
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_items.length < 2 || !widget.store.canOrder) {
      return const SizedBox.shrink();
    }
    final l10n = AppLocalizations.of(context);
    final textTheme = Theme.of(context).textTheme;
    return Padding(
      key: const Key('food-item-addons'),
      padding: const EdgeInsets.only(top: DealGoSpacing.s16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(l10n.foodItemAddonsTitle, style: DealGoType.subtitle(textTheme)),
          const SizedBox(height: DealGoSpacing.s8),
          SizedBox(
            height: _tileHeight,
            child: ListView.separated(
              key: const Key('food-item-addons-list'),
              scrollDirection: Axis.horizontal,
              itemCount: _items.length,
              separatorBuilder: (context, index) =>
                  const SizedBox(width: DealGoSpacing.s8),
              itemBuilder: (context, index) {
                final item = _items[index];
                return _AddonTile(
                  key: Key('food-addon-${item.id}'),
                  item: item,
                  onAdd: () => _add(item),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _AddonTile extends StatelessWidget {
  const _AddonTile({required this.item, required this.onAdd, super.key});

  final FoodFeaturedItem item;
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final textTheme = Theme.of(context).textTheme;
    return Material(
      color: DealGoColors.card,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(DealGoRadius.input),
        side: BorderSide(color: DealGoColors.border),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onAdd,
        child: SizedBox(
          width: _tileWidth,
          child: Padding(
            padding: const EdgeInsets.all(_tileInset),
            child: Row(
              children: [
                FoodThumb(size: _thumbSize, imageUrl: item.imageUrl),
                const SizedBox(width: DealGoSpacing.s8),
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: DealGoType.body(textTheme).copyWith(
                          fontWeight: FontWeight.w700,
                          color: DealGoColors.text,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        formatVnd(item.priceVnd),
                        style: DealGoType.meta(textTheme)
                            .copyWith(color: DealGoColors.textSecondary),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: DealGoSpacing.s8),
                SizedBox(
                  width: _addSize,
                  height: _addSize,
                  child: Material(
                    color: DealGoColors.primary,
                    shape: const CircleBorder(),
                    clipBehavior: Clip.antiAlias,
                    child: Semantics(
                      button: true,
                      label: '${l10n.foodAddToCart}: ${item.name}',
                      onTap: onAdd,
                      excludeSemantics: true,
                      child: Tooltip(
                        message: l10n.foodAddToCart,
                        child: InkWell(
                          key: Key('food-addon-add-${item.id}'),
                          onTap: onAdd,
                          child: const Icon(
                            DealGoIcons.add,
                            size: 20,
                            color: Colors.white,
                          ),
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
