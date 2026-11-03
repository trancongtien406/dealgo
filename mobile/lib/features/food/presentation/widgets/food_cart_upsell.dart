import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/design_system/icons/dealgo_icons.dart';
import '../../../../core/design_system/tokens/dealgo_tokens.dart';
import '../../../../core/design_system/tokens/dealgo_type_scale.dart';
import '../../../../l10n/app_localizations.dart';
import '../../domain/entities/food_models.dart';
import '../../domain/entities/food_money.dart';
import '../../domain/params/get_food_store_params.dart';
import '../../domain/usecases/get_food_store.dart';
import '../cubit/food_cart_cubit.dart';
import 'food_widgets.dart';

const int foodUpsellMaxItems = 6;

/// Dishes from [store] worth adding to [cart]: on sale, a different menu
/// group than anything already in the cart, and not already a line.
/// Best sellers first, then by name so the strip is stable.
List<FoodMenuItem> foodUpsellItems({
  required FoodStoreDetail store,
  required FoodCartState cart,
  int max = foodUpsellMaxItems,
}) {
  if (cart.storeId != store.id || cart.lines.isEmpty) {
    return const [];
  }
  final byId = {for (final item in store.items) item.id: item};
  final inCart = <String>{for (final line in cart.lines) line.placeItemId};
  final coveredGroups = <String?>{};
  for (final id in inCart) {
    final item = byId[id];
    if (item != null) {
      coveredGroups.add(item.menuCategoryId);
    }
  }
  final candidates = <FoodMenuItem>[
    for (final item in store.items)
      if (item.onSale &&
          !inCart.contains(item.id) &&
          !coveredGroups.contains(item.menuCategoryId) &&
          item.optionGroups.every((group) => !group.required))
        item,
  ];
  candidates.sort((a, b) {
    final sold = b.soldCount.compareTo(a.soldCount);
    return sold != 0 ? sold : a.name.compareTo(b.name);
  });
  return candidates.take(max).toList(growable: false);
}

class FoodCartUpsellStrip extends StatefulWidget {
  const FoodCartUpsellStrip({super.key});

  @override
  State<FoodCartUpsellStrip> createState() => _FoodCartUpsellStripState();
}

class _FoodCartUpsellStripState extends State<FoodCartUpsellStrip> {
  FoodStoreDetail? _store;
  String? _requestedStoreId;
  var _loading = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final storeId = context.read<FoodCartCubit>().state.storeId;
    if (storeId == null || storeId.isEmpty || _loading) {
      return;
    }
    final token = currentAccessToken(context);
    if (token == null) {
      return;
    }
    _requestedStoreId = storeId;
    _loading = true;
    try {
      final store = await context.read<GetFoodStore>()(
        GetFoodStoreParams(accessToken: token, storeId: storeId),
      );
      if (!mounted) {
        return;
      }
      setState(() {
        _store = store;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) {
        return;
      }
      setState(() {
        _store = null;
        _loading = false;
      });
    }
  }

  void _add(FoodMenuItem item) {
    final store = _store;
    if (store == null) {
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

  @override
  Widget build(BuildContext context) {
    return BlocListener<FoodCartCubit, FoodCartState>(
      listenWhen: (previous, next) => previous.storeId != next.storeId,
      listener: (context, state) {
        if (state.storeId != _requestedStoreId) {
          _load();
        }
      },
      child: BlocBuilder<FoodCartCubit, FoodCartState>(
        buildWhen: (previous, next) =>
            previous.storeId != next.storeId ||
            !_sameUpsellLines(previous.lines, next.lines),
        builder: (context, cart) {
          final store = _store;
          if (store == null || store.id != cart.storeId) {
            return const SizedBox.shrink();
          }
          final items = foodUpsellItems(store: store, cart: cart);
          if (items.isEmpty) {
            return const SizedBox.shrink();
          }
          return _UpsellPanel(items: items, onAdd: _add);
        },
      ),
    );
  }
}

bool _sameUpsellLines(List<FoodCartLine> left, List<FoodCartLine> right) {
  if (left.length != right.length) {
    return false;
  }
  for (var i = 0; i < left.length; i++) {
    if (left[i].itemId != right[i].itemId) {
      return false;
    }
  }
  return true;
}

class _UpsellPanel extends StatelessWidget {
  const _UpsellPanel({required this.items, required this.onAdd});

  final List<FoodMenuItem> items;
  final ValueChanged<FoodMenuItem> onAdd;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final textTheme = Theme.of(context).textTheme;
    return FoodPanel(
      key: const Key('food-cart-upsell'),
      elevated: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(l10n.foodCartUpsellTitle, style: DealGoType.subtitle(textTheme)),
          const SizedBox(height: DealGoSpacing.s8),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                for (final item in items) ...[
                  SizedBox(
                    width: 190,
                    child: _UpsellTile(item: item, onAdd: () => onAdd(item)),
                  ),
                  if (item != items.last)
                    const SizedBox(width: DealGoSpacing.s8),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _UpsellTile extends StatelessWidget {
  const _UpsellTile({required this.item, required this.onAdd});

  final FoodMenuItem item;
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final textTheme = Theme.of(context).textTheme;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: DealGoColors.canvas,
        borderRadius: BorderRadius.circular(DealGoRadius.input),
        border: Border.all(color: DealGoColors.border),
      ),
      child: Padding(
        padding: const EdgeInsets.all(DealGoSpacing.s8),
        child: Row(
          children: [
            FoodThumb(size: 36, imageUrl: item.imageUrl),
            const SizedBox(width: DealGoSpacing.s8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    item.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: DealGoType.meta(textTheme).copyWith(
                      fontWeight: FontWeight.w700,
                      color: DealGoColors.text,
                    ),
                  ),
                  Text(
                    formatVnd(item.priceVnd),
                    style: DealGoType.meta(textTheme)
                        .copyWith(color: DealGoColors.textSecondary),
                  ),
                ],
              ),
            ),
            SizedBox(
              width: 32,
              height: 32,
              child: Material(
                color: DealGoColors.primary,
                shape: const CircleBorder(),
                clipBehavior: Clip.antiAlias,
                child: InkWell(
                  key: Key('food-cart-upsell-add-${item.id}'),
                  onTap: onAdd,
                  child: Tooltip(
                    message: l10n.foodAddToCart,
                    child: const Icon(
                      DealGoIcons.add,
                      size: 18,
                      color: Colors.white,
                    ),
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
