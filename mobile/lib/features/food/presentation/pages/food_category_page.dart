import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/design_system/components/dealgo_skeleton.dart';
import '../../../../core/design_system/components/dealgo_state_view.dart';
import '../../../../core/design_system/tokens/dealgo_tokens.dart';
import '../../../../core/design_system/tokens/dealgo_type_scale.dart';
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
import '../widgets/food_filter_sheet.dart';
import '../widgets/food_widgets.dart';
import '../widgets/food_store_card.dart';
import '../food_categories_store.dart';
import '../../../../core/design_system/icons/dealgo_icons.dart';
import '../../../../core/design_system/components/dealgo_app_header.dart';
import '../../../../core/design_system/components/dealgo_refresh.dart';

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
  var _filters = const FoodFilters();

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

  Future<void> _reload() {
    final origin = foodCartOrigin(context);
    return context.read<FoodDiscoveryCubit>().load(
      currentAccessToken(context),
      lat: origin.lat,
      lng: origin.lng,
      sortBy: _filters.sortBy,
      maxKm: _filters.maxKm,
      category: widget.categoryCode,
    );
  }

  void _setSort(String sortBy) {
    if (_filters.sortBy == sortBy) return;
    setState(() => _filters = _filters.copyWith(sortBy: sortBy));
    _reload();
  }

  Future<void> _openFilters() async {
    final next = await showFoodFilterSheet(context: context, current: _filters);
    if (next == null || !mounted || next == _filters) {
      return;
    }
    final serverChanged =
        next.sortBy != _filters.sortBy || next.maxKm != _filters.maxKm;
    setState(() => _filters = next);
    if (serverChanged) {
      _reload();
    }
  }

  /// The radius filter only applies when the request has an origin, so
  /// coordinates plus an empty *unfiltered* feed is the one case that means
  /// "out of coverage"; everything else is simply an empty catalogue/category.
  String _emptyTitle(AppLocalizations l10n, FoodDiscoveryState discovery) {
    final ready = discovery is FoodDiscoveryReady ? discovery : null;
    final outOfArea =
        ready != null && ready.hasLocation && widget.categoryCode == null;
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
    final allStores = switch (discovery) {
      FoodDiscoveryReady(:final stores) => stores,
      _ => <FoodStoreSummary>[],
    };
    final stores = [
      for (final store in allStores)
        if (_filters.matches(store, rating: ratings[store.id])) store,
    ];
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
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            DealGoAppHeader(title: title),
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: DealGoDimensions.pageGutter,
              ),
              child: Row(
                children: [
                  Expanded(
                    child: InkWell(
                      onTap: () => context.push(FoodRoutes.search),
                      borderRadius: BorderRadius.circular(DealGoRadius.button),
                      child: InputDecorator(
                        decoration: InputDecoration(
                          filled: true,
                          fillColor: DealGoColors.card,
                          prefixIcon: const Icon(
                            DealGoIcons.search,
                            color: DealGoColors.primary,
                          ),
                          contentPadding: const EdgeInsets.symmetric(
                            vertical: DealGoSpacing.s12,
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(
                              DealGoRadius.button,
                            ),
                            borderSide: BorderSide(color: DealGoColors.border),
                          ),
                        ),
                        child: Text(
                          l10n.foodDiscoverySearchHint,
                          style: DealGoType.body(textTheme)
                              .copyWith(color: DealGoColors.textSecondary),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: DealGoSpacing.s8),
                  FoodFilterIconButton(
                    buttonKey: const Key('food-category-filter'),
                    activeCount: _filters.activeCount,
                    onTap: _openFilters,
                  ),
                ],
              ),
            ),
            const SizedBox(height: DealGoSpacing.s12),
            // Wrap so pills stay left-aligned and never clip or hide off-screen.
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: DealGoDimensions.pageGutter,
              ),
              child: Wrap(
                spacing: DealGoSpacing.s8,
                runSpacing: DealGoSpacing.s8,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  FoodFilterPill(
                    key: const Key('food-sort-near'),
                    label: l10n.foodCategorySortNear,
                    icon: DealGoIcons.myLocation,
                    selected: _filters.sortBy == 'distance',
                    onTap: () => _setSort('distance'),
                  ),
                  FoodFilterPill(
                    key: const Key('food-sort-rating'),
                    label: l10n.foodCategorySortRating,
                    icon: DealGoIcons.starFilled,
                    selected: _filters.sortBy == 'rating',
                    onTap: () => _setSort('rating'),
                  ),
                  FoodFilterPill(
                    key: const Key('food-sort-newest'),
                    label: l10n.foodSearchSortNewest,
                    icon: DealGoIcons.stars,
                    selected: _filters.sortBy == 'createdAt',
                    onTap: () => _setSort('createdAt'),
                  ),
                  if (_filters.sortBy == 'name')
                    FoodFilterPill(
                      key: const Key('food-sort-name'),
                      label: l10n.foodFilterSortName,
                      icon: DealGoIcons.list,
                      selected: true,
                      onTap: _openFilters,
                    ),
                  Container(width: 1, height: 18, color: DealGoColors.border),
                  FoodFilterPill(
                    key: const Key('food-category-filter-open'),
                    label: l10n.foodFilterOpenNow,
                    icon: DealGoIcons.clock,
                    selected: _filters.openNow,
                    onTap: () => setState(
                      () => _filters = _filters.copyWith(
                        openNow: !_filters.openNow,
                      ),
                    ),
                  ),
                  FoodFilterPill(
                    key: const Key('food-category-filter-offers'),
                    label: l10n.foodFilterOffers,
                    icon: DealGoIcons.tag,
                    selected: _filters.offersOnly,
                    onTap: () => setState(
                      () => _filters = _filters.copyWith(
                        offersOnly: !_filters.offersOnly,
                      ),
                    ),
                  ),
                  if (_filters.maxKm != null)
                    FoodFilterPill(
                      key: const Key('food-category-filter-km'),
                      label: l10n.foodFilterKm(_filters.maxKm!),
                      icon: DealGoIcons.pin,
                      selected: true,
                      onTap: _openFilters,
                    ),
                  if (_filters.minRating != null)
                    FoodFilterPill(
                      key: const Key('food-category-filter-min-rating'),
                      label: formatMinRatingLabel(l10n, _filters.minRating!),
                      icon: DealGoIcons.starFilled,
                      selected: true,
                      onTap: _openFilters,
                    ),
                  if (_filters.maxEtaMinutes != null)
                    FoodFilterPill(
                      key: const Key('food-category-filter-max-eta'),
                      label: l10n.foodFilterEtaMax(_filters.maxEtaMinutes!),
                      icon: DealGoIcons.timer,
                      selected: true,
                      onTap: _openFilters,
                    ),
                  if (_filters.noMinOrder)
                    FoodFilterPill(
                      key: const Key('food-category-filter-no-min-order'),
                      label: l10n.foodFilterNoMinOrder,
                      icon: DealGoIcons.successOutline,
                      selected: true,
                      onTap: () => setState(
                        () => _filters = _filters.copyWith(noMinOrder: false),
                      ),
                    ),
                ],
              ),
            ),
            if (discovery is FoodDiscoveryReady && discovery.isRefreshing)
              const Padding(
                padding: EdgeInsets.only(top: DealGoSpacing.s8),
                child: LinearProgressIndicator(minHeight: 2),
              ),
            Expanded(
              child: DealGoRefresh(
                onRefresh: _reload,
                child: discovery is FoodDiscoveryFailed
                    ? DealGoStateView.failure(
                        context,
                        onRetry: _reload,
                        cause: discovery.message.error,
                        message: discovery.message.resolve(l10n),
                      )
                    : loading
                    ? const DealGoSkeletonList(
                        itemCount: 4,
                        padding: EdgeInsets.symmetric(
                          horizontal: DealGoDimensions.pageGutter,
                          vertical: DealGoSpacing.s12,
                        ),
                      )
                    : stores.isEmpty
                    ? DealGoStateView(
                        key: const Key('food-category-empty'),
                        art: DealGoStateArt.noSearch,
                        title: _emptyTitle(l10n, discovery),
                      )
                    : ListView(
                        controller: _scroll,
                        padding: const EdgeInsets.fromLTRB(
                          DealGoDimensions.pageGutter,
                          DealGoSpacing.s12,
                          DealGoDimensions.pageGutter,
                          DealGoSpacing.s24,
                        ),
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  l10n.foodCategoryAroundYou,
                                  style: textTheme.titleMedium,
                                ),
                              ),
                              if (discovery is FoodDiscoveryReady)
                                Text(
                                  l10n.foodCategoryAroundHint(discovery.total),
                                  style: textTheme.bodySmall?.copyWith(
                                    color: DealGoColors.textSecondary,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                            ],
                          ),
                          const SizedBox(height: DealGoSpacing.s16),
                          for (final (index, store) in stores.indexed) ...[
                            DealGoStaggerIn(
                              key: ValueKey(store.id),
                              index: index,
                              child: _StoreRow(
                                store: store,
                                rating: ratings[store.id],
                                onTap: () =>
                                    context.push(FoodRoutes.store(store.id)),
                              ),
                            ),
                            const SizedBox(height: DealGoSpacing.s12),
                          ],
                          FoodFeedFooter(
                            state: discovery is FoodDiscoveryReady
                                ? discovery
                                : null,
                            onRetry: () =>
                                context.read<FoodDiscoveryCubit>().loadMore(),
                          ),
                        ],
                      ),
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
