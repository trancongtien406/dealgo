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
import '../widgets/food_feed_footer.dart';
import '../widgets/food_widgets.dart';
import '../widgets/food_store_card.dart';
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
    final origin = foodCartOrigin(context);
    return BlocProvider(
      create: (context) =>
          FoodDiscoveryCubit(
            listFoodStores: context.read<ListFoodStores>(),
            ratings: context.read<RatingRepository>(),
            location: context.read<LocationService>(),
          )..load(
            currentAccessToken(context),
            lat: origin.lat,
            lng: origin.lng,
            sortBy: 'distance',
            category: categoryCode,
          ),
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
  final ScrollController _scroll = ScrollController();
  var _sort = 'near';

  @override
  void initState() {
    super.initState();
    _scroll.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scroll.removeListener(_onScroll);
    _scroll.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (!_scroll.hasClients) return;
    final position = _scroll.position;
    if (position.maxScrollExtent <= 0) return;
    if (position.pixels < position.maxScrollExtent - 400) return;
    final discovery = context.read<FoodDiscoveryCubit>().state;
    if (discovery is FoodDiscoveryReady && discovery.loadMoreFailed) return;
    context.read<FoodDiscoveryCubit>().loadMore();
  }

  void _setSort(String sort) {
    if (_sort == sort) return;
    setState(() => _sort = sort);
    final origin = foodCartOrigin(context);
    context.read<FoodDiscoveryCubit>().load(
      currentAccessToken(context),
      lat: origin.lat,
      lng: origin.lng,
      sortBy: sort == 'rating' ? 'rating' : 'distance',
      category: widget.categoryCode,
    );
  }

  /// Empty results blame distance only when distance can explain them: the
  /// load had no GPS fix, or the unfiltered nearby feed found nothing at all.
  String _emptyTitle(AppLocalizations l10n, FoodDiscoveryState discovery) {
    final ready = discovery is FoodDiscoveryReady ? discovery : null;
    final outOfArea =
        ready != null && (!ready.hasLocation || widget.categoryCode == null);
    return outOfArea
        ? l10n.foodEmptyOutOfArea
        : l10n.foodEmptyNoStoresInCategory;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final textTheme = Theme.of(context).textTheme;
    final discovery = context.watch<FoodDiscoveryCubit>().state;
    final ratings = switch (discovery) {
      FoodDiscoveryReady(:final ratings) => ratings,
      _ => const <String, StoreRating>{},
    };
    final stores = switch (discovery) {
      FoodDiscoveryReady(:final stores) => stores,
      _ => <FoodStoreSummary>[],
    };
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
                    suffixIcon: Icon(
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
            // Sized by the chips (no fixed 40pt strip) so large text never clips.
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(
                horizontal: DealGoDimensions.pageGutter,
              ),
              child: Row(
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
                      onTap: () => _setSort(entry.$1),
                    ),
                    const SizedBox(width: DealGoSpacing.s8),
                  ],
                ],
              ),
            ),
            if (discovery is FoodDiscoveryReady && discovery.isRefreshing)
              const Padding(
                padding: EdgeInsets.only(top: DealGoSpacing.s8),
                child: LinearProgressIndicator(minHeight: 2),
              ),
            Expanded(
              child: ListView(
                controller: _scroll,
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
                            if (discovery is FoodDiscoveryReady)
                              Text(
                                l10n.foodCategoryAroundHint(discovery.total),
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
                      onRetry: () {
                        final origin = foodCartOrigin(context);
                        context.read<FoodDiscoveryCubit>().load(
                          currentAccessToken(context),
                          lat: origin.lat,
                          lng: origin.lng,
                          sortBy: _sort == 'rating' ? 'rating' : 'distance',
                          category: widget.categoryCode,
                        );
                      },
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
                      title: _emptyTitle(l10n, discovery),
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
                  FoodFeedFooter(
                    state: discovery is FoodDiscoveryReady ? discovery : null,
                    onRetry: () =>
                        context.read<FoodDiscoveryCubit>().loadMore(),
                  ),
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
    return FoodStoreCard(store: store, rating: rating, onTap: onTap);
  }
}
