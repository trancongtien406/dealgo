import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/network/api_exception.dart';
import '../../../../core/design_system/components/dealgo_banner.dart';
import '../../../../core/design_system/components/dealgo_bottom_bar.dart';
import '../../../../core/design_system/components/dealgo_primary_button.dart';
import '../../../../core/design_system/components/dealgo_skeleton.dart';
import '../../../../core/design_system/components/dealgo_state_view.dart';
import '../../../../core/network/request_failure.dart';
import '../../../../core/design_system/tokens/dealgo_tokens.dart';
import '../../../../l10n/app_localizations.dart';
import '../../domain/entities/food_models.dart';
import '../../domain/entities/food_money.dart';
import '../../domain/usecases/get_food_store.dart';
import '../cubit/food_cart_cubit.dart';
import 'food_item_options_page.dart';
import '../utils/food_routes.dart';
import '../cubit/food_store_cubit.dart';
import '../widgets/food_widgets.dart';
import '../widgets/store_meta.dart';
import '../../../driver_card/presentation/driver_card_tile.dart'
    show formatRatingAverage;
import '../../../rating/domain/service_rating.dart';
import '../../../rating/presentation/rate_service_card.dart';

import 'package:intl/intl.dart';

import '../../../../core/design_system/icons/dealgo_icons.dart';
import '../../../../core/l10n/api_error_text.dart';
import '../../../../core/design_system/components/dealgo_app_header.dart';

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
  StoreReviews? _reviews;
  var _loading = true;
  Object? _failure;
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
        _failure = sessionExpiredFailure;
      });
      return;
    }
    setState(() {
      _loading = true;
      _failure = null;
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
      unawaited(_loadReviews(token));
    } on ApiException catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _loading = false;
        _failure = error;
      });
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _loading = false;
        _failure = error;
      });
    }
  }

  /// Best effort: the heading simply shows no rating when this fails.
  Future<void> _loadReviews(String token) async {
    try {
      final reviews = await context.read<RatingRepository>().storeReviews(
        accessToken: token,
        storeId: widget.storeId,
      );
      if (mounted) setState(() => _reviews = reviews);
    } on Object {
      // Ratings are optional here; the menu stays usable without them.
      return;
    }
  }

  @override
  Widget build(BuildContext context) {
    final store = _store;
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      backgroundColor: DealGoColors.canvas,
      extendBody: store != null,
      body: SafeArea(
        bottom: store == null ? dealGoSafeAreaBottom(context) : false,
        child: Column(
          children: [
            DealGoAppHeader(title: l10n.foodStoreTitle),
            Expanded(
              child: store == null
                  ? _StoreStatus(
                      loading: _loading,
                      failure: _failure,
                      onRetry: _load,
                    )
                  : ListView(
                      padding: const EdgeInsets.fromLTRB(
                        DealGoDimensions.pageGutter,
                        0,
                        DealGoDimensions.pageGutter,
                        DealGoSpacing.s24 +
                            DealGoDimensions.buttonMinHeight +
                            DealGoSpacing.s48,
                      ),
                      children: [
                        _Hero(store: store),
                        const SizedBox(height: DealGoSpacing.s16),
                        _StoreHeading(store: store, rating: _reviews?.summary),
                        const SizedBox(height: DealGoSpacing.s16),
                        _Tabs(
                          selected: _tab,
                          onSelected: (tab) => setState(() => _tab = tab),
                        ),
                        const SizedBox(height: DealGoSpacing.s16),
                        switch (_tab) {
                          _StoreTab.menu => _Menu(store: store),
                          _StoreTab.reviews => _Reviews(reviews: _reviews),
                          _StoreTab.info => _StoreInfo(store: store),
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
  const _Hero({required this.store});

  final FoodStoreDetail store;

  @override
  Widget build(BuildContext context) {
    final gallery = <String>[
      if ((store.logoUrl ?? '').isNotEmpty) store.logoUrl!,
      for (final item in store.items)
        if ((item.imageUrl ?? '').isNotEmpty) item.imageUrl!,
    ];
    final unique = gallery.toSet().toList(growable: false);
    return FoodCoverImage(
      imageUrl: unique.isEmpty ? null : unique.first,
      height: 200,
      badge: unique.length > 1
          ? DecoratedBox(
              decoration: BoxDecoration(
                color: DealGoColors.scrim,
                borderRadius: BorderRadius.circular(DealGoRadius.pill),
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: DealGoSpacing.s8,
                  vertical: DealGoSpacing.s4,
                ),
                child: Text(
                  '1/${unique.length}',
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            )
          : null,
    );
  }
}

class _StoreHeading extends StatelessWidget {
  const _StoreHeading({required this.store, this.rating});

  final FoodStoreDetail store;
  final StoreRating? rating;

  @override
  Widget build(BuildContext context) {
    final open = store.openNow && store.items.any((item) => item.available);
    final today = store.schedule.hoursConfigured
        ? store.schedule.day(
            DateTime.now().toUtc().add(const Duration(hours: 7)).weekday,
          )
        : null;
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
                  open
                      ? l10n.foodStoreOpen
                      : store.closedReason == StoreClosedReason.closed
                      ? l10n.foodStoreClosedLabel
                      : l10n.foodStorePaused,
                  style: textTheme.labelSmall?.copyWith(
                    color: open
                        ? DealGoColors.brandGreen
                        : DealGoColors.warning,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
          ],
        ),
        if (store.closedReason != null ||
            store.serviceMode == StoreServiceMode.busy) ...[
          const SizedBox(height: DealGoSpacing.s8),
          DealGoBanner(
            key: const Key('food-store-mode-banner'),
            tone: store.closedReason != null
                ? DealGoBannerTone.warning
                : DealGoBannerTone.info,
            message: switch (store.closedReason) {
              StoreClosedReason.paused => l10n.foodStorePausedBanner,
              StoreClosedReason.closed => l10n.foodStoreClosedBanner,
              null => l10n.foodStoreBusyBanner,
            },
          ),
        ],
        if (store.schedule.hoursConfigured) ...[
          const SizedBox(height: DealGoSpacing.s4),
          Text(
            today == null
                ? l10n.foodStoreHoursTodayOff
                : l10n.foodStoreHoursToday(
                    today.overnight
                        ? l10n.foodStoreHoursOvernight(
                            '${today.opensAt} – ${today.closesAt}',
                          )
                        : '${today.opensAt} – ${today.closesAt}',
                  ),
            key: const Key('food-store-hours-today'),
            style: textTheme.bodySmall,
          ),
        ],
        const SizedBox(height: DealGoSpacing.s8),
        StoreMetaLine(
          store: FoodStoreSummary(
            id: store.id,
            name: store.name,
            category: store.category,
          ),
          rating: rating,
        ),
        if (store.openNow && store.estimatedPrepMinutes != null) ...[
          const SizedBox(height: DealGoSpacing.s12),
          Wrap(
            key: const Key('food-store-prep-estimate'),
            spacing: DealGoSpacing.s8,
            runSpacing: DealGoSpacing.s8,
            children: [
              FoodInfoChip(
                label: l10n.foodStorePrepChip(store.estimatedPrepMinutes!),
                icon: DealGoIcons.motorbike,
                filled: true,
              ),
            ],
          ),
        ],
      ],
    );
  }
}

class _Tabs extends StatelessWidget {
  const _Tabs({required this.selected, required this.onSelected});

  final _StoreTab selected;
  final ValueChanged<_StoreTab> onSelected;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final tabs = <(_StoreTab, String)>[
      (_StoreTab.menu, l10n.foodStoreTabMenu),
      (_StoreTab.reviews, l10n.foodStoreTabReviews),
      (_StoreTab.info, l10n.foodStoreTabInfo),
    ];
    return DecoratedBox(
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: DealGoColors.border)),
      ),
      child: Row(
        children: [
          for (final tab in tabs)
            Expanded(
              child: InkWell(
                key: Key('food-store-tab-${tab.$1.name}'),
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
                    padding: const EdgeInsets.fromLTRB(
                      DealGoSpacing.s4,
                      DealGoSpacing.s8,
                      DealGoSpacing.s4,
                      DealGoSpacing.s12,
                    ),
                    child: Text(
                      tab.$2,
                      maxLines: 1,
                      softWrap: false,
                      overflow: TextOverflow.fade,
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
      ),
    );
  }
}

class _Menu extends StatelessWidget {
  const _Menu({required this.store});

  final FoodStoreDetail store;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    if (store.items.isEmpty) {
      return FoodPanel(child: Text(l10n.foodStoreNoItems));
    }
    final textTheme = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(l10n.foodStoreBestsellers, style: textTheme.titleMedium),
                  Text(
                    l10n.foodStoreMenuCount(store.items.length),
                    style: textTheme.bodySmall,
                  ),
                ],
              ),
            ),
          ],
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
    final l10n = AppLocalizations.of(context);
    final description = item.description?.trim();
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
          elevated: true,
          padding: const EdgeInsets.all(DealGoSpacing.s12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              FoodThumb(size: 72, imageUrl: item.imageUrl),
              const SizedBox(width: DealGoSpacing.s12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.name,
                      style: textTheme.titleMedium?.copyWith(fontSize: 16),
                    ),
                    if (description != null && description.isNotEmpty) ...[
                      const SizedBox(height: DealGoSpacing.s4),
                      Text(
                        description,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: textTheme.bodySmall,
                      ),
                    ],
                    if (item.prepMinutes != null) ...[
                      const SizedBox(height: DealGoSpacing.s4),
                      Row(
                        children: [
                          const Icon(
                            DealGoIcons.clock,
                            size: 12,
                            color: DealGoColors.textSecondary,
                          ),
                          const SizedBox(width: DealGoSpacing.s4),
                          Text(
                            l10n.foodStorePrepChip(item.prepMinutes!),
                            style: textTheme.bodySmall,
                          ),
                        ],
                      ),
                    ],
                    const SizedBox(height: DealGoSpacing.s8),
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            formatVnd(item.priceVnd),
                            style: textTheme.titleMedium?.copyWith(
                              color: DealGoColors.primary,
                              fontWeight: FontWeight.w800,
                              fontSize: 16,
                            ),
                          ),
                        ),
                        if (!item.available)
                          Text(
                            l10n.foodItemSoldOut,
                            style: textTheme.bodySmall?.copyWith(
                              color: DealGoColors.danger,
                            ),
                          )
                        else
                          _QuantityControl(store: store, item: item),
                      ],
                    ),
                  ],
                ),
              ),
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
    final hasOptions = item.optionGroups.isNotEmpty;
    if (quantity == 0) {
      return IconButton(
        key: Key('food-add-${item.id}'),
        tooltip: AppLocalizations.of(context).foodAddToCart,
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
        icon: const Icon(DealGoIcons.add),
      );
    }
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton(
          tooltip: AppLocalizations.of(context).foodDecreaseQuantity,
          onPressed: () => cart.adjustCatalogQuantity(item.id, -1),
          icon: const Icon(DealGoIcons.remove),
        ),
        Text('$quantity', style: Theme.of(context).textTheme.titleMedium),
        IconButton(
          key: Key('food-add-${item.id}'),
          tooltip: AppLocalizations.of(context).foodAddToCart,
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
          icon: const Icon(DealGoIcons.add),
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
    return DealGoBottomBar(
      child: Row(
        children: [
          Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                AppLocalizations.of(context).foodCartSelected(cart.itemCount),
                style: textTheme.bodySmall,
              ),
              Text(
                formatVnd(cart.subtotalVnd),
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
              label: AppLocalizations.of(context).foodViewCart,
              trailingIcon: DealGoIcons.arrowRight,
              // One review screen: store → checkout (cart page merged).
              onPressed: () => context.push(FoodRoutes.checkout),
            ),
          ),
        ],
      ),
    );
  }
}

class _StoreStatus extends StatelessWidget {
  const _StoreStatus({
    required this.loading,
    required this.failure,
    required this.onRetry,
  });

  final bool loading;
  final Object? failure;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    if (loading) {
      return const Padding(
        padding: EdgeInsets.all(DealGoDimensions.pageGutter),
        child: DealGoSkeletonList(itemCount: 5, padding: EdgeInsets.zero),
      );
    }
    final l10n = AppLocalizations.of(context);
    final message = failure is ApiException
        ? apiErrorText(l10n, failure as ApiException)
        : l10n.errorLoadFailed;
    return DealGoStateView.failure(
      context,
      onRetry: onRetry,
      cause: failure,
      message: message,
    );
  }
}

class _Reviews extends StatelessWidget {
  const _Reviews({required this.reviews});

  final StoreReviews? reviews;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final textTheme = Theme.of(context).textTheme;
    final data = reviews;
    if (data == null) {
      return FoodPanel(child: Text(l10n.foodStoreReviewsUnavailable));
    }
    final summary = data.summary;
    final average = summary.average;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        FoodPanel(
          child: Row(
            children: [
              const Icon(DealGoIcons.star, color: DealGoColors.amber),
              const SizedBox(width: DealGoSpacing.s8),
              Expanded(
                child: Text(
                  average == null
                      ? (summary.count == 0
                            ? l10n.foodStoreReviewsNone
                            : l10n.foodStoreReviewsHidden(summary.count))
                      : l10n.foodStoreReviewsSummary(
                          formatRatingAverage(context, average),
                          summary.count,
                        ),
                  key: const Key('food-store-review-summary'),
                  style: textTheme.titleSmall,
                ),
              ),
            ],
          ),
        ),
        for (final review in data.items) ...[
          const SizedBox(height: DealGoSpacing.s12),
          FoodPanel(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    for (var i = 0; i < 5; i++)
                      Icon(
                        DealGoIcons.star,
                        size: 14,
                        color: i < review.stars
                            ? DealGoColors.amber
                            : DealGoColors.border,
                      ),
                    const Spacer(),
                    Text(
                      DateFormat('dd/MM/yyyy').format(review.createdAt),
                      style: textTheme.labelSmall?.copyWith(
                        color: DealGoColors.textSecondary,
                      ),
                    ),
                  ],
                ),
                if (review.tags.isNotEmpty) ...[
                  const SizedBox(height: DealGoSpacing.s8),
                  Text(
                    [for (final tag in review.tags) ratingTagLabel(l10n, tag)]
                        .join(' · '),
                    style: textTheme.bodySmall?.copyWith(
                      color: DealGoColors.primary,
                    ),
                  ),
                ],
                if (review.comment != null) ...[
                  const SizedBox(height: DealGoSpacing.s8),
                  Text(review.comment!, style: textTheme.bodyMedium),
                ],
              ],
            ),
          ),
        ],
      ],
    );
  }
}

class _StoreInfo extends StatelessWidget {
  const _StoreInfo({required this.store});

  final FoodStoreDetail store;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final textTheme = Theme.of(context).textTheme;
    final category = storeCategoryLabel(l10n, store.category);
    Widget row(IconData icon, String label, String value) => Padding(
      padding: const EdgeInsets.symmetric(vertical: DealGoSpacing.s4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: DealGoColors.textSecondary),
          const SizedBox(width: DealGoSpacing.s8),
          SizedBox(width: 96, child: Text(label, style: textTheme.bodySmall)),
          Expanded(child: Text(value, style: textTheme.bodyMedium)),
        ],
      ),
    );
    return FoodPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          row(DealGoIcons.store, l10n.foodStoreInfoName, store.name),
          if (category != null)
            row(DealGoIcons.restaurant, l10n.foodStoreInfoCategory, category),
          row(
            DealGoIcons.pin,
            l10n.foodStoreInfoAddress,
            store.addressLabel ?? l10n.foodStoreInfoAddressMissing,
          ),
          row(
            DealGoIcons.wallet,
            l10n.foodStoreInfoPayment,
            l10n.foodStoreInfoPaymentCod,
          ),
        ],
      ),
    );
  }
}
