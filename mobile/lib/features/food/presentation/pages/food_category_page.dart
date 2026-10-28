import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/design_system/components/dealgo_chip.dart';
import '../../../../core/design_system/components/dealgo_skeleton.dart';
import '../../../../core/design_system/components/dealgo_state_view.dart';
import '../../../../core/design_system/tokens/dealgo_tokens.dart';
import '../../../../core/motion/dealgo_motion_widgets.dart';
import '../../../../l10n/app_localizations.dart';
import '../../domain/entities/food_models.dart';
import '../../domain/usecases/list_food_stores.dart';
import '../../../../core/location/location_service.dart';
import '../../../rating/domain/service_rating.dart';
import '../cubit/food_discovery_cubit.dart';
import '../utils/food_routes.dart';
import '../widgets/food_cart_bar.dart';
import '../widgets/food_widgets.dart';
import '../widgets/food_badges.dart';
import '../food_categories_store.dart';
import '../../../../core/design_system/icons/dealgo_icons.dart';
import '../../../../core/design_system/components/dealgo_app_header.dart';

/// C024 — category / nearby store results list.
class FoodCategoryPage extends StatelessWidget {
  const FoodCategoryPage({this.categoryCode, super.key});

  /// Admin-managed category code; null = every store.
  final String? categoryCode;

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) => FoodDiscoveryCubit(
        listFoodStores: context.read<ListFoodStores>(),
        ratings: context.read<RatingRepository>(),
        location: context.read<LocationService>(),
      )..load(currentAccessToken(context)),
      child: _FoodCategoryView(categoryCode: categoryCode),
    );
  }
}

class _FoodCategoryView extends StatefulWidget {
  const _FoodCategoryView({this.categoryCode});

  final String? categoryCode;

  @override
  State<_FoodCategoryView> createState() => _FoodCategoryViewState();
}

class _FoodCategoryViewState extends State<_FoodCategoryView> {
  var _sort = 'near';

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final textTheme = Theme.of(context).textTheme;
    final discovery = context.watch<FoodDiscoveryCubit>().state;
    final ratings = switch (discovery) {
      FoodDiscoveryReady(:final ratings) => ratings,
      _ => const <String, StoreRating>{},
    };
    final code = widget.categoryCode?.trim().toLowerCase();
    final stores = switch (discovery) {
      FoodDiscoveryReady(:final stores) => [
        for (final store in stores)
          if (code == null ||
              code.isEmpty ||
              store.category?.toLowerCase() == code)
            store,
      ],
      _ => <FoodStoreSummary>[],
    };
    if (_sort == 'rating') {
      stores.sort(
        (a, b) => (ratings[b.id]?.average ?? -1).compareTo(
          ratings[a.id]?.average ?? -1,
        ),
      );
    } else {
      stores.sort(
        (a, b) => (a.distanceKm ?? double.infinity).compareTo(
          b.distanceKm ?? double.infinity,
        ),
      );
    }
    final loading = discovery is FoodDiscoveryLoading;
    final title =
        foodCategoryLabel(context, widget.categoryCode) ??
        l10n.foodCategoryTitle;

    return Scaffold(
      // The body's SafeArea sits above the bar while the cart has items.
      extendBody: true,
      bottomNavigationBar: const FoodCartBar(),
      backgroundColor: DealGoColors.canvas,
      body: SafeArea(
        child: Column(
          children: [
            DealGoAppHeader(title: title),
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: DealGoDimensions.pageGutter,
              ),
              child: InkWell(
                onTap: () => context.push(FoodRoutes.search),
                borderRadius: BorderRadius.circular(DealGoRadius.input),
                child: InputDecorator(
                  decoration: InputDecoration(
                    prefixIcon: const Icon(
                      DealGoIcons.search,
                      color: DealGoColors.primary,
                    ),
                    suffixIcon: const Icon(
                      DealGoIcons.edit,
                      color: DealGoColors.textSecondary,
                    ),
                    filled: true,
                    fillColor: DealGoColors.subtlePurple,
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(DealGoRadius.input),
                      borderSide: BorderSide.none,
                    ),
                  ),
                  child: Text(
                    l10n.foodDiscoverySearchHint,
                    style: textTheme.bodyMedium?.copyWith(
                      color: DealGoColors.textSecondary,
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: DealGoSpacing.s12),
            SizedBox(
              height: 40,
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(
                  horizontal: DealGoDimensions.pageGutter,
                ),
                children: [
                  for (final entry in [
                    ('near', l10n.foodCategorySortNear),
                    ('rating', l10n.foodCategorySortRating),
                  ]) ...[
                    DealGoChip(
                      key: Key('food-sort-${entry.$1}'),
                      label: entry.$2,
                      selected: _sort == entry.$1,
                      tone: DealGoChipTone.brand,
                      onTap: () => setState(() => _sort = entry.$1),
                    ),
                    const SizedBox(width: DealGoSpacing.s8),
                  ],
                ],
              ),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(
                  DealGoDimensions.pageGutter,
                  DealGoSpacing.s16,
                  DealGoDimensions.pageGutter,
                  DealGoSpacing.s24,
                ),
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              l10n.foodCategoryAroundYou,
                              style: textTheme.titleMedium,
                            ),
                            Text(
                              l10n.foodCategoryAroundHint(stores.length),
                              style: textTheme.bodySmall,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: DealGoSpacing.s16),
                  if (discovery is FoodDiscoveryFailed)
                    DealGoStateView.failure(
                      context,
                      onRetry: () => context.read<FoodDiscoveryCubit>().load(
                        currentAccessToken(context),
                      ),
                      cause: discovery.message.error,
                      message: discovery.message.resolve(l10n),
                      compact: true,
                    )
                  else if (loading)
                    const DealGoSkeletonList(itemCount: 4)
                  else if (stores.isEmpty)
                    DealGoStateView(
                      key: const Key('food-category-empty'),
                      art: DealGoStateArt.noSearch,
                      title: l10n.foodCategoryEmpty,
                      compact: true,
                    )
                  else
                    for (final (index, store) in stores.indexed) ...[
                      DealGoStaggerIn(
                        key: ValueKey(store.id),
                        index: index,
                        child: _StoreRow(
                          store: store,
                          rating: ratings[store.id],
                          onTap: () => context.push(FoodRoutes.store(store.id)),
                        ),
                      ),
                      const SizedBox(height: DealGoSpacing.s12),
                    ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StoreRow extends StatelessWidget {
  const _StoreRow({required this.store, required this.onTap, this.rating});

  final FoodStoreSummary store;
  final StoreRating? rating;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return FoodStoreListCard(store: store, rating: rating, onTap: onTap);
  }
}
