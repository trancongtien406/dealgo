import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/network/api_error_l10n.dart';
import '../../../../core/network/api_exception.dart';
import '../../../../core/design_system/components/dealgo_primary_button.dart';
import '../../../../core/design_system/tokens/dealgo_tokens.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../identity/presentation/widgets/auth_widgets.dart';
import '../../domain/entities/food_models.dart';
import '../../domain/entities/food_money.dart';
import '../../domain/usecases/get_food_store.dart';
import '../cubit/food_cart_cubit.dart';
import 'food_item_options_page.dart';
import 'food_item_options_sheet.dart';
import '../utils/food_routes.dart';
import '../cubit/food_store_cubit.dart';
import '../widgets/food_widgets.dart';

class FoodStorePage extends StatelessWidget {
  const FoodStorePage({required this.storeId, super.key});

  final String storeId;

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) =>
          FoodStoreCubit(getFoodStore: context.read<GetFoodStore>()),
      child: _FoodStoreView(storeId: storeId),
    );
  }
}

class _FoodStoreView extends StatefulWidget {
  const _FoodStoreView({required this.storeId});

  final String storeId;

  @override
  State<_FoodStoreView> createState() => _FoodStorePageState();
}

class _FoodStorePageState extends State<_FoodStoreView> {
  FoodStoreDetail? _store;
  var _loading = true;
  String? _error;
  var _tab = _StoreTab.menu;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    final token = currentAccessToken(context);
    if (token == null) {
      setState(() {
        _loading = false;
        _error = sessionExpiredMessage(context);
      });
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final store = await context.read<FoodStoreCubit>().load(
        accessToken: token,
        storeId: widget.storeId,
      );
      if (!mounted) {
        return;
      }
      setState(() {
        _store = store;
        _loading = false;
      });
    } on ApiException catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _loading = false;
        _error = error.message;
      });
    } catch (_) {
      if (!mounted) {
        return;
      }
      setState(() {
        _loading = false;
        _error = networkErrorMessage(context);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final store = _store;
    return Scaffold(
      backgroundColor: DealGoColors.canvas,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            FoodScreenHeader(
              title: 'Chi tiết quán',
              trailing: const DealGoWordmark(),
            ),
            Expanded(
              child: store == null
                  ? _StoreStatus(
                      loading: _loading,
                      error: _error,
                      onRetry: _load,
                    )
                  : ListView(
                      padding: const EdgeInsets.fromLTRB(
                        DealGoDimensions.pageGutter,
                        0,
                        DealGoDimensions.pageGutter,
                        DealGoSpacing.s24,
                      ),
                      children: [
                        const _Hero(),
                        const SizedBox(height: DealGoSpacing.s16),
                        _StoreHeading(store: store),
                        const SizedBox(height: DealGoSpacing.s16),
                        _Tabs(
                          selected: _tab,
                          onSelected: (tab) => setState(() => _tab = tab),
                        ),
                        const SizedBox(height: DealGoSpacing.s16),
                        switch (_tab) {
                          _StoreTab.menu => _Menu(store: store),
                          _StoreTab.reviews => const FoodPanel(
                            child: Text('Chưa có đánh giá từ máy chủ.'),
                          ),
                          _StoreTab.info => FoodPanel(child: Text(store.name)),
                        },
                      ],
                    ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: store == null ? null : _CartBar(storeId: store.id),
    );
  }
}

enum _StoreTab { menu, reviews, info }

class _Hero extends StatelessWidget {
  const _Hero();

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(DealGoRadius.card),
      child: const SizedBox(
        height: 180,
        width: double.infinity,
        child: ColoredBox(
          color: Color(0xFFFFF4EA),
          child: Icon(Icons.ramen_dining, color: Color(0xFFEA580C), size: 72),
        ),
      ),
    );
  }
}

class _StoreHeading extends StatelessWidget {
  const _StoreHeading({required this.store});

  final FoodStoreDetail store;

  @override
  Widget build(BuildContext context) {
    final open = store.items.any((item) => item.available);
    final textTheme = Theme.of(context).textTheme;
    final l10n = AppLocalizations.of(context);
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
                  open ? 'Đang mở' : 'Tạm ngưng',
                  style: textTheme.labelSmall?.copyWith(
                    color:
                        open ? DealGoColors.brandGreen : DealGoColors.warning,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: DealGoSpacing.s8),
        Text(
          '⭐ 4,8 (1,2k đánh giá) · Món Việt',
          style: textTheme.bodySmall,
        ),
        const SizedBox(height: DealGoSpacing.s12),
        Wrap(
          spacing: DealGoSpacing.s8,
          runSpacing: DealGoSpacing.s8,
          children: [
            _MetaChip(
              icon: Icons.two_wheeler,
              label: '20–30 phút',
              background: DealGoColors.subtlePurple,
              foreground: DealGoColors.primary,
            ),
            _MetaChip(
              icon: Icons.place_outlined,
              label: '1,1 km',
              background: DealGoColors.canvas,
              foreground: DealGoColors.textSecondary,
            ),
            DecoratedBox(
              decoration: BoxDecoration(
                color: DealGoColors.greenSurface,
                borderRadius: BorderRadius.circular(999),
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: DealGoSpacing.s12,
                  vertical: DealGoSpacing.s8,
                ),
                child: Text(
                  l10n.foodFreeshipChip,
                  style: textTheme.labelSmall?.copyWith(
                    color: DealGoColors.brandGreen,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: DealGoSpacing.s12),
        DecoratedBox(
          decoration: BoxDecoration(
            color: DealGoColors.subtlePurple,
            borderRadius: BorderRadius.circular(DealGoRadius.input),
            border: Border.all(
              color: DealGoColors.primary.withValues(alpha: 0.35),
              style: BorderStyle.solid,
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.all(DealGoSpacing.s12),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Deal ngon hôm nay',
                        style: textTheme.titleSmall?.copyWith(
                          color: DealGoColors.primary,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      Text(
                        'Ưu đãi theo chương trình cửa hàng (minh họa)',
                        style: textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
                DecoratedBox(
                  decoration: BoxDecoration(
                    color: const Color(0xFFFCE7F3),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: DealGoSpacing.s8,
                      vertical: DealGoSpacing.s4,
                    ),
                    child: Text(
                      'Deal',
                      style: textTheme.labelSmall?.copyWith(
                        color: const Color(0xFFDB2777),
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _MetaChip extends StatelessWidget {
  const _MetaChip({
    required this.icon,
    required this.label,
    required this.background,
    required this.foreground,
  });

  final IconData icon;
  final String label;
  final Color background;
  final Color foreground;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: DealGoSpacing.s12,
          vertical: DealGoSpacing.s8,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14, color: foreground),
            const SizedBox(width: 4),
            Text(
              label,
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: foreground,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Tabs extends StatelessWidget {
  const _Tabs({required this.selected, required this.onSelected});

  final _StoreTab selected;
  final ValueChanged<_StoreTab> onSelected;

  @override
  Widget build(BuildContext context) {
    const tabs = <(_StoreTab, String)>[
      (_StoreTab.menu, 'Thực đơn'),
      (_StoreTab.reviews, 'Đánh giá'),
      (_StoreTab.info, 'Thông tin'),
    ];
    return Row(
      children: [
        for (final tab in tabs)
          Expanded(
            child: InkWell(
              onTap: () => onSelected(tab.$1),
              child: DecoratedBox(
                decoration: BoxDecoration(
                  border: Border(
                    bottom: BorderSide(
                      color: selected == tab.$1
                          ? DealGoColors.primary
                          : Colors.transparent,
                      width: 2,
                    ),
                  ),
                ),
                child: Padding(
                  padding: const EdgeInsets.only(bottom: DealGoSpacing.s8),
                  child: Text(
                    tab.$2,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: selected == tab.$1
                          ? DealGoColors.primary
                          : DealGoColors.textSecondary,
                      fontWeight: selected == tab.$1
                          ? FontWeight.w700
                          : FontWeight.w500,
                    ),
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class _Menu extends StatelessWidget {
  const _Menu({required this.store});

  final FoodStoreDetail store;

  @override
  Widget build(BuildContext context) {
    if (store.items.isEmpty) {
      return const FoodPanel(child: Text('Cửa hàng chưa có món.'));
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Món bán chạy', style: Theme.of(context).textTheme.titleMedium),
        Text(
          'Gợi ý từ thực đơn cửa hàng',
          style: Theme.of(context).textTheme.bodySmall,
        ),
        const SizedBox(height: DealGoSpacing.s12),
        for (final item in store.items) ...[
          _MenuItem(store: store, item: item),
          const SizedBox(height: DealGoSpacing.s12),
        ],
      ],
    );
  }
}

class _MenuItem extends StatelessWidget {
  const _MenuItem({required this.store, required this.item});

  final FoodStoreDetail store;
  final FoodMenuItem item;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: item.available
            ? () => openFoodItemOptions(
                context: context,
                store: store,
                item: item,
              )
            : null,
        borderRadius: BorderRadius.circular(DealGoRadius.card),
        child: FoodPanel(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const FoodThumb(),
              const SizedBox(width: DealGoSpacing.s12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.name,
                      style: textTheme.titleMedium?.copyWith(fontSize: 16),
                    ),
                    const SizedBox(height: DealGoSpacing.s4),
                    Text(
                      '⭐ 4,8 · 20–30 phút',
                      style: textTheme.bodySmall,
                    ),
                    const SizedBox(height: DealGoSpacing.s8),
                    DecoratedBox(
                      decoration: BoxDecoration(
                        color: DealGoColors.greenSurface,
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: DealGoSpacing.s8,
                          vertical: DealGoSpacing.s4,
                        ),
                        child: Text(
                          AppLocalizations.of(context).foodFreeshipChip,
                          style: textTheme.labelSmall?.copyWith(
                            color: DealGoColors.brandGreen,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: DealGoSpacing.s4),
                    Text(
                      formatVnd(item.priceVnd),
                      style: textTheme.titleMedium?.copyWith(
                        color: DealGoColors.primary,
                        fontSize: 16,
                      ),
                    ),
                    if (!item.available)
                      Text(
                        'Hết món',
                        style: textTheme.bodySmall?.copyWith(
                          color: DealGoColors.danger,
                        ),
                      ),
                  ],
                ),
              ),
              _QuantityControl(store: store, item: item),
            ],
          ),
        ),
      ),
    );
  }
}

class _QuantityControl extends StatelessWidget {
  const _QuantityControl({required this.store, required this.item});

  final FoodStoreDetail store;
  final FoodMenuItem item;

  @override
  Widget build(BuildContext context) {
    if (!item.available) {
      return const SizedBox.shrink();
    }
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
    final cart = context.read<FoodCartCubit>();
    final hasOptions = foodOptionGroupsForItem(item.id).isNotEmpty;
    if (quantity == 0) {
      return IconButton(
        key: Key('food-add-${item.id}'),
        tooltip: 'Thêm vào giỏ',
        onPressed: () {
          if (hasOptions) {
            openFoodItemOptions(context: context, store: store, item: item);
            return;
          }
          cart.addItem(storeId: store.id, storeName: store.name, item: item);
        },
        style: IconButton.styleFrom(
          backgroundColor: DealGoColors.primary,
          foregroundColor: Colors.white,
        ),
        icon: const Icon(Icons.add),
      );
    }
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton(
          tooltip: 'Giảm số lượng',
          onPressed: () => cart.adjustCatalogQuantity(item.id, -1),
          icon: const Icon(Icons.remove),
        ),
        Text('$quantity', style: Theme.of(context).textTheme.titleMedium),
        IconButton(
          key: Key('food-add-${item.id}'),
          tooltip: 'Thêm vào giỏ',
          onPressed: quantity >= foodLineQuantityMax
              ? null
              : () {
                  if (hasOptions) {
                    openFoodItemOptions(
                      context: context,
                      store: store,
                      item: item,
                    );
                    return;
                  }
                  cart.addItem(
                    storeId: store.id,
                    storeName: store.name,
                    item: item,
                  );
                },
          icon: const Icon(Icons.add),
        ),
      ],
    );
  }
}

class _CartBar extends StatelessWidget {
  const _CartBar({required this.storeId});

  final String storeId;

  @override
  Widget build(BuildContext context) {
    final cart = context.watch<FoodCartCubit>().state;
    if (cart.storeId != storeId || cart.itemCount == 0) {
      return const SizedBox.shrink();
    }
    final textTheme = Theme.of(context).textTheme;
    return DecoratedBox(
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
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${cart.itemCount} món đã chọn',
                    style: textTheme.bodySmall,
                  ),
                  Text(
                    formatVnd(cart.subtotalVnd),
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
                  label: 'Xem giỏ hàng',
                  onPressed: () => context.push(FoodRoutes.cart),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StoreStatus extends StatelessWidget {
  const _StoreStatus({
    required this.loading,
    required this.error,
    required this.onRetry,
  });

  final bool loading;
  final String? error;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    if (loading) {
      return const Center(child: Text('Đang tải thực đơn'));
    }
    return Padding(
      padding: const EdgeInsets.all(DealGoDimensions.pageGutter),
      child: FoodPanel(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(error ?? AppLocalizations.of(context).errorLoadFailed),
            const SizedBox(height: DealGoSpacing.s12),
            TextButton(
              onPressed: onRetry,
              child: Text(AppLocalizations.of(context).actionRetry),
            ),
          ],
        ),
      ),
    );
  }
}
