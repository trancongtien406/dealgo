import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/config/api_base_url.dart';
import '../../../../core/design_system/components/dealgo_profile_avatar.dart';
import '../../../../core/design_system/components/dealgo_state_view.dart';
import '../../../../core/design_system/components/dealgo_haptics.dart';
import '../../../../core/design_system/tokens/dealgo_tokens.dart';
import '../../../../core/motion/dealgo_motion_widgets.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../home_banner/presentation/home_banner_carousel.dart';
import '../../../identity/domain/entities/app_role.dart';
import '../../../identity/presentation/cubit/auth_cubit.dart';
import '../../../identity/presentation/widgets/auth_widgets.dart';
import '../../../places/domain/place.dart';
import '../../../places/presentation/place_picker_page.dart';
import '../../domain/entities/food_category.dart';
import '../../domain/entities/food_models.dart';
import '../../domain/entities/food_money.dart';
import '../../domain/usecases/list_food_stores.dart';
import '../../../../core/location/location_service.dart';
import '../../../rating/domain/service_rating.dart';
import '../cubit/food_cart_cubit.dart';
import '../cubit/food_discovery_cubit.dart';
import '../widgets/food_cart_bar.dart';
import '../utils/food_routes.dart';
import '../widgets/food_widgets.dart';
import '../food_categories_store.dart';
import '../widgets/food_category_tile.dart';
import '../widgets/food_badges.dart';
import '../widgets/food_store_card.dart';
import '../widgets/food_filter_sheet.dart';
import '../widgets/food_reorder_strip.dart';
import '../widgets/food_voucher_wall.dart';
import '../widgets/food_feed_footer.dart';
import '../widgets/store_meta.dart';
import '../../../../core/design_system/icons/dealgo_icons.dart';
import '../../../../core/design_system/components/dealgo_skeleton.dart';
import '../../../../core/design_system/components/dealgo_nav_insets.dart';
import '../../../../core/design_system/components/dealgo_network_image.dart';
import '../../../../core/design_system/components/dealgo_refresh.dart';

class FoodDiscoveryPage extends StatelessWidget {
  const FoodDiscoveryPage({super.key});

  @override
  Widget build(BuildContext context) {
    final origin = foodCartOrigin(context);
    return BlocProvider(
      create: (context) => FoodDiscoveryCubit(
        listFoodStores: context.read<ListFoodStores>(),
        ratings: context.read<RatingRepository>(),
        location: context.read<LocationService>(),
      )..load(currentAccessToken(context), lat: origin.lat, lng: origin.lng),
      child: const _FoodDiscoveryView(),
    );
  }
}

class _FoodDiscoveryView extends StatefulWidget {
  const _FoodDiscoveryView();

  @override
  State<_FoodDiscoveryView> createState() => _FoodDiscoveryViewState();
}

class _FoodDiscoveryViewState extends State<_FoodDiscoveryView> {
  final ScrollController _scroll = ScrollController();
  final GlobalKey _storesKey = GlobalKey();
  var _filters = const FoodFilters();
  var _refreshToken = 0;

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

  Future<void> _reload() async {
    final origin = foodCartOrigin(context);
    final categoriesFuture = maybeFoodCategories(
      context,
      listen: false,
    )?.load();
    setState(() => _refreshToken++);
    await Future.wait([
      context.read<FoodDiscoveryCubit>().load(
        currentAccessToken(context),
        lat: origin.lat,
        lng: origin.lng,
        sortBy: _filters.sortBy,
        maxKm: _filters.maxKm,
      ),
      ?categoriesFuture,
    ]);
  }

  Future<void> _pickAddress() async {
    final place = await pickPlace(context, PlacePickPurpose.delivery);
    if (place == null || !mounted) {
      return;
    }
    context.read<FoodCartCubit>().setDropoff(
      label: place.label,
      lat: place.lat,
      lng: place.lng,
    );
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

  void _openStore(FoodStoreSummary store) {
    context.push(FoodRoutes.store(store.id));
  }

  @override
  Widget build(BuildContext context) {
    final discovery = context.watch<FoodDiscoveryCubit>().state;
    final ready = discovery is FoodDiscoveryReady ? discovery : null;
    final allStores = ready?.stores ?? const <FoodStoreSummary>[];
    final fetched = ready?.ratings ?? const <String, StoreRating>{};
    final stores = [
      for (final store in allStores)
        if (_filters.matches(store, rating: fetched[store.id])) store,
    ];
    // Inline list ratings fill in until the summary fetch lands.
    final ratings = <String, StoreRating>{
      for (final store in stores)
        store.id: ?storeRatingOf(store, fetched[store.id]),
    };
    final offerStores = [
      for (final store in stores)
        if (store.offers.isNotEmpty && store.closedReason == null) store,
    ];
    final l10n = AppLocalizations.of(context);
    final dishes = [
      for (final store in stores)
        if (store.closedReason == null)
          for (final item in store.featuredItems) (store: store, item: item),
    ];
    final deals = [
      for (final dish in dishes)
        if ((dish.item.originalPriceVnd ?? 0) > dish.item.priceVnd) dish,
    ];
    final newDishes = [
      for (final dish in dishes)
        if (dish.item.isNew) dish,
    ];
    final loading = discovery is FoodDiscoveryLoading;
    final refreshing = ready?.isRefreshing ?? false;
    final error = discovery is FoodDiscoveryFailed ? discovery.message : null;
    final popular = _popularThisWeek(stores, ratings);
    final cartRoom = FoodCartBar.showsFor(context.watch<FoodCartCubit>().state)
        ? kFoodCartBarRoom
        : 0.0;
    final bottomInset = dealGoScrollPadding(context, EdgeInsets.zero).bottom;
    const gutter = DealGoDimensions.pageGutter;
    return Stack(
      children: [
        SafeArea(
          bottom: false,
          child: DealGoRefresh(
            onRefresh: _reload,
            child: CustomScrollView(
              controller: _scroll,
              slivers: [
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(
                    gutter,
                    DealGoSpacing.s8,
                    gutter,
                    0,
                  ),
                  sliver: SliverList.list(
                    children: [
                      _DiscoveryHeader(onPickAddress: _pickAddress),
                      const SizedBox(height: DealGoSpacing.s16),
                      _SearchRow(
                        onOpenSearch: () => context.push(FoodRoutes.search),
                        onOpenFilters: _openFilters,
                        activeFilterCount: _filters.activeCount,
                      ),
                      _HeaderSlot(
                        child: refreshing
                            ? const LinearProgressIndicator(minHeight: 2)
                            : null,
                      ),
                      _HeaderSlot(
                        child: _filters.isDefault
                            ? null
                            : _ActiveFilterSummary(
                                filters: _filters,
                                onEdit: _openFilters,
                                onClear: () {
                                  setState(
                                    () => _filters = const FoodFilters(),
                                  );
                                  _reload();
                                },
                              ),
                      ),
                      const SizedBox(height: DealGoSpacing.s12),
                      _CategoryStrip(
                        selected: null,
                        onSelected: (code) =>
                            context.push(FoodRoutes.categoryOf(code)),
                      ),
                      const SizedBox(height: DealGoSpacing.s8),
                      HomeBannerCarousel(
                        role: AppRole.customer,
                        service: 'FOOD',
                        gapBelow: DealGoSpacing.s16,
                        refreshToken: _refreshToken,
                      ),
                      FoodVoucherWall(refreshToken: _refreshToken),
                      FoodReorderStrip(refreshToken: _refreshToken),
                      // Curated collections are bounded (a horizontal strip per
                      // row), so they stay above the endless store list. Below
                      // it they would be pushed down by every appended page.
                      if (offerStores.isNotEmpty) ...[
                        _SectionHeader(
                          title: l10n.foodOffersNearTitle,
                          onSeeAll: () =>
                              context.push(FoodRoutes.categoryOf(null)),
                        ),
                        const SizedBox(height: DealGoSpacing.s12),
                        _OfferStrip(stores: offerStores, onOpen: _openStore),
                        const SizedBox(height: DealGoSpacing.s20),
                      ],
                      if (deals.isNotEmpty) ...[
                        _SectionHeader(
                          title: l10n.foodCollectionDeals,
                          onSeeAll: () =>
                              context.push(FoodRoutes.categoryOf(null)),
                        ),
                        const SizedBox(height: DealGoSpacing.s12),
                        _DishStrip(
                          key: const Key('food-deals-strip'),
                          dishes: deals,
                          onOpen: _openStore,
                        ),
                        const SizedBox(height: DealGoSpacing.s20),
                      ],
                      if (newDishes.isNotEmpty) ...[
                        _SectionHeader(
                          title: l10n.foodCollectionNewDishes,
                          onSeeAll: () =>
                              context.push(FoodRoutes.categoryOf(null)),
                        ),
                        const SizedBox(height: DealGoSpacing.s12),
                        _DishStrip(
                          key: const Key('food-new-strip'),
                          dishes: newDishes,
                          onOpen: _openStore,
                        ),
                        const SizedBox(height: DealGoSpacing.s20),
                      ],
                      if (popular.isNotEmpty) ...[
                        _SectionHeader(
                          title: l10n.foodCollectionTopRated,
                          onSeeAll: () =>
                              context.push(FoodRoutes.categoryOf(null)),
                        ),
                        const SizedBox(height: DealGoSpacing.s12),
                        _StoreStrip(
                          key: const Key('food-top-stores-strip'),
                          stores: popular,
                          ratings: ratings,
                          onOpen: _openStore,
                        ),
                        const SizedBox(height: DealGoSpacing.s20),
                      ],
                      KeyedSubtree(
                        key: _storesKey,
                        child: _SectionHeader(
                          title: l10n.foodCollectionNear,
                          onSeeAll: () =>
                              context.push(FoodRoutes.categoryOf(null)),
                        ),
                      ),
                      const SizedBox(height: DealGoSpacing.s12),
                    ],
                  ),
                ),
                if (loading)
                  SliverPadding(
                    padding: const EdgeInsets.symmetric(horizontal: gutter),
                    sliver: const SliverToBoxAdapter(
                      child: DealGoSkeletonList(itemCount: 4),
                    ),
                  )
                else if (error != null)
                  SliverPadding(
                    padding: const EdgeInsets.symmetric(horizontal: gutter),
                    sliver: SliverToBoxAdapter(
                      child: DealGoStateView.failure(
                        context,
                        onRetry: _reload,
                        cause: error.error,
                        message: error.resolve(l10n),
                      ),
                    ),
                  )
                else if (stores.isEmpty)
                  SliverPadding(
                    padding: const EdgeInsets.symmetric(horizontal: gutter),
                    sliver: SliverToBoxAdapter(
                      child: DealGoStateView(
                        art: DealGoStateArt.noSearch,
                        title: l10n.emptyStoresNearby,
                        message: l10n.emptyStoresNearbyBody,
                        compact: true,
                      ),
                    ),
                  )
                else
                  SliverPadding(
                    padding: const EdgeInsets.symmetric(horizontal: gutter),
                    sliver: SliverList.separated(
                      itemCount: stores.length,
                      itemBuilder: (context, index) {
                        final store = stores[index];
                        return DealGoStaggerIn(
                          index: index,
                          child: FoodStoreCard(
                            key: Key('food-store-card-${store.id}'),
                            store: store,
                            rating: ratings[store.id],
                            onTap: () => _openStore(store),
                          ),
                        );
                      },
                      separatorBuilder: (context, index) =>
                          const SizedBox(height: DealGoSpacing.s12),
                    ),
                  ),
                if (stores.isNotEmpty)
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(
                      gutter,
                      DealGoSpacing.s12,
                      gutter,
                      0,
                    ),
                    sliver: SliverToBoxAdapter(
                      child: FoodFeedFooter(
                        state: ready,
                        onRetry: () =>
                            context.read<FoodDiscoveryCubit>().loadMore(),
                      ),
                    ),
                  ),
                SliverToBoxAdapter(
                  child: SizedBox(
                    height:
                        DealGoSpacing.s20 +
                        DealGoSpacing.s16 +
                        cartRoom +
                        bottomInset,
                  ),
                ),
              ],
            ),
          ),
        ),
        // Above the role tab bar while the cart holds something.
        const Positioned(left: 0, right: 0, bottom: 0, child: FoodCartBar()),
      ],
    );
  }
}

/// Best average first; only stores that already publish a score.
List<FoodStoreSummary> _popularThisWeek(
  List<FoodStoreSummary> stores,
  Map<String, StoreRating> ratings,
) {
  double? scoreOf(FoodStoreSummary store) =>
      storeRatingOf(store, ratings[store.id])?.average;

  final rated = [
    for (final store in stores)
      if (scoreOf(store) != null && store.closedReason == null) store,
  ]..sort((a, b) => scoreOf(b)!.compareTo(scoreOf(a)!));
  return rated.take(4).toList(growable: false);
}

class _DiscoveryHeader extends StatelessWidget {
  const _DiscoveryHeader({required this.onPickAddress});

  final VoidCallback onPickAddress;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const DealGoWordmark(),
        const SizedBox(width: DealGoSpacing.s12),
        Expanded(
          child: Align(
            alignment: Alignment.centerRight,
            child: _LocationChip(onTap: onPickAddress),
          ),
        ),
        const SizedBox(width: DealGoSpacing.s8),
        const _DiscoveryAvatar(),
      ],
    );
  }
}

class _DiscoveryAvatar extends StatelessWidget {
  const _DiscoveryAvatar();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final avatarUrl = accountAvatarUrl(context.watch<AuthCubit>().state);
    return SizedBox(
      width: 36,
      height: 36,
      child: Stack(
        fit: StackFit.expand,
        children: [
          DealGoProfileAvatar(
            key: const Key('food-discovery-avatar'),
            avatarUrl: avatarUrl,
            size: 36,
            semanticLabel: l10n.accountTitle,
          ),
          // The ripple sits above the opaque photo, not beneath it.
          Material(
            color: Colors.transparent,
            shape: const CircleBorder(),
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              onTap: () => context.go('/customer/account'),
              child: const SizedBox.expand(),
            ),
          ),
        ],
      ),
    );
  }
}

class _LocationChip extends StatelessWidget {
  const _LocationChip({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final rawAddress = context.select<FoodCartCubit, String>(
      (cart) => cart.state.dropoffLabel,
    );
    final chosen = rawAddress.trim().isNotEmpty;
    final label = chosen ? shortPlaceLabel(rawAddress) : l10n.foodDeliverTo;
    return Material(
      color: chosen ? DealGoColors.card : DealGoColors.subtlePurple,
      shape: StadiumBorder(
        side: BorderSide(
          color: chosen ? DealGoColors.border : Colors.transparent,
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Semantics(
          button: true,
          label: '${l10n.foodDeliverTo} $label',
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: DealGoSpacing.s8,
              vertical: DealGoSpacing.s8,
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  DealGoIcons.pinFilled,
                  color: DealGoColors.primary,
                  size: 16,
                ),
                const SizedBox(width: 4),
                Flexible(
                  child: Text(
                    label,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: chosen ? DealGoColors.text : DealGoColors.primary,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                Icon(
                  DealGoIcons.expandMore,
                  size: 16,
                  color: DealGoColors.textSecondary,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// "Gần tôi" plus the Admin-managed categories; shimmer tiles while the
/// list loads, just "Gần tôi" if it failed with nothing cached.
class _CategoryStrip extends StatelessWidget {
  const _CategoryStrip({required this.selected, required this.onSelected});

  /// Null = "Gần tôi".
  final String? selected;
  final ValueChanged<String?> onSelected;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final store = maybeFoodCategories(context);
    final categories = store?.items ?? const <FoodCategory>[];
    final loading = store?.status == FoodCategoriesStatus.loading;
    final language = Localizations.localeOf(context).languageCode;
    final textStyle = Theme.of(context).textTheme.labelSmall;
    Widget tile({
      required Key key,
      required bool active,
      required Widget avatar,
      required String label,
      required VoidCallback onTap,
    }) => InkWell(
      key: key,
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: SizedBox(
        width: 64,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            avatar,
            const SizedBox(height: DealGoSpacing.s4),
            Text(
              label,
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: textStyle?.copyWith(
                color: DealGoColors.text,
                fontWeight: active ? FontWeight.w700 : FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
    final children = <Widget>[
      tile(
        key: const Key('food-category-near'),
        active: selected == null,
        avatar: Container(
          width: 56,
          height: 56,
          decoration: BoxDecoration(
            color: DealGoColors.subtlePurple,
            shape: BoxShape.circle,
            border: selected == null
                ? Border.all(color: DealGoColors.primary, width: 1.5)
                : null,
          ),
          child: const Center(
            child: Icon(
              DealGoIcons.myLocation,
              color: DealGoColors.primary,
              size: 26,
            ),
          ),
        ),
        label: l10n.foodGroupNear,
        onTap: () => onSelected(null),
      ),
      if (loading && categories.isEmpty)
        for (var i = 0; i < 4; i++)
          const SizedBox(width: 64, child: FoodCategoryTileSkeleton()),
      for (final category in categories)
        tile(
          key: Key('food-category-${category.code}'),
          active: selected == category.code,
          avatar: FoodCategoryAvatar(
            category: category,
            selected: selected == category.code,
          ),
          label: category.name(language),
          onTap: () => onSelected(category.code),
        ),
    ];
    return SizedBox(
      height: 84,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: children.length,
        separatorBuilder: (context, index) =>
            const SizedBox(width: DealGoSpacing.s8),
        itemBuilder: (context, index) => children[index],
      ),
    );
  }
}

class _SearchRow extends StatelessWidget {
  const _SearchRow({
    required this.onOpenSearch,
    required this.onOpenFilters,
    required this.activeFilterCount,
  });

  final VoidCallback onOpenSearch;
  final VoidCallback onOpenFilters;
  final int activeFilterCount;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Row(
      children: [
        Expanded(
          child: InkWell(
            key: const Key('food-search-entry'),
            onTap: onOpenSearch,
            borderRadius: BorderRadius.circular(DealGoRadius.input),
            child: InputDecorator(
              decoration: InputDecoration(
                filled: true,
                fillColor: DealGoColors.card,
                isDense: true,
                prefixIcon: const Icon(
                  DealGoIcons.search,
                  color: DealGoColors.primary,
                  size: 20,
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: DealGoSpacing.s16,
                  vertical: DealGoSpacing.s14,
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(DealGoRadius.input),
                  borderSide: BorderSide(color: DealGoColors.border),
                ),
              ),
              child: Text(
                l10n.foodDiscoverySearchHint,
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  color: DealGoColors.textTertiary,
                ),
              ),
            ),
          ),
        ),
        const SizedBox(width: DealGoSpacing.s8),
        FoodFilterIconButton(
          buttonKey: const Key('food-discovery-filter'),
          activeCount: activeFilterCount,
          onTap: onOpenFilters,
        ),
      ],
    );
  }
}

/// Reserves its place in the feed header whether or not [child] is present:
/// optional rows appearing above the banner must not shift the sliver children
/// below, since a shifted index rebuilds them and re-requests their data.
class _HeaderSlot extends StatelessWidget {
  const _HeaderSlot({this.child});

  final Widget? child;

  @override
  Widget build(BuildContext context) {
    final value = child;
    if (value == null) {
      return const SizedBox.shrink();
    }
    return Padding(
      padding: const EdgeInsets.only(top: DealGoSpacing.s8),
      child: value,
    );
  }
}

class _ActiveFilterSummary extends StatelessWidget {
  const _ActiveFilterSummary({
    required this.filters,
    required this.onEdit,
    required this.onClear,
  });

  final FoodFilters filters;
  final VoidCallback onEdit;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final km = filters.maxKm;
    final minRating = filters.minRating;
    final maxEta = filters.maxEtaMinutes;
    return Wrap(
      spacing: DealGoSpacing.s8,
      runSpacing: DealGoSpacing.s4,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        if (filters.sortBy != 'distance')
          FoodFilterPill(
            label: foodSortLabel(l10n, filters.sortBy),
            icon: foodSortIcon(filters.sortBy),
            selected: true,
            onTap: onEdit,
          ),
        if (km != null)
          FoodFilterPill(
            label: l10n.foodFilterKm(km),
            icon: DealGoIcons.pin,
            selected: true,
            onTap: onEdit,
          ),
        if (minRating != null)
          FoodFilterPill(
            label: formatMinRatingLabel(l10n, minRating),
            icon: DealGoIcons.starFilled,
            selected: true,
            onTap: onEdit,
          ),
        if (maxEta != null)
          FoodFilterPill(
            label: l10n.foodFilterEtaMax(maxEta),
            icon: DealGoIcons.timer,
            selected: true,
            onTap: onEdit,
          ),
        if (filters.openNow)
          FoodFilterPill(
            label: l10n.foodFilterOpenNow,
            icon: DealGoIcons.clock,
            selected: true,
            onTap: onEdit,
          ),
        if (filters.offersOnly)
          FoodFilterPill(
            label: l10n.foodFilterOffers,
            icon: DealGoIcons.tag,
            selected: true,
            onTap: onEdit,
          ),
        if (filters.noMinOrder)
          FoodFilterPill(
            label: l10n.foodFilterNoMinOrder,
            icon: DealGoIcons.successOutline,
            selected: true,
            onTap: onEdit,
          ),
        TextButton(
          key: const Key('food-filter-clear'),
          onPressed: onClear,
          child: Text(
            l10n.foodFilterClear,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: DealGoColors.primary,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ],
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title, required this.onSeeAll});

  final String title;
  final VoidCallback onSeeAll;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Row(
      children: [
        Expanded(child: Text(title, style: textTheme.titleMedium)),
        TextButton(
          onPressed: onSeeAll,
          style: TextButton.styleFrom(
            foregroundColor: DealGoColors.primary,
            padding: const EdgeInsets.symmetric(horizontal: DealGoSpacing.s8),
            minimumSize: Size.zero,
            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          ),
          child: Text(AppLocalizations.of(context).foodSeeAll),
        ),
      ],
    );
  }
}

class _StoreCover extends StatelessWidget {
  const _StoreCover({this.imageUrl});

  final String? imageUrl;

  @override
  Widget build(BuildContext context) {
    final resolved = resolveMediaUrl(imageUrl);
    final placeholder = Container(
      width: double.infinity,
      height: double.infinity,
      color: DealGoColors.subtlePurple,
      child: Center(
        child: Icon(
          DealGoIcons.restaurant,
          size: 48,
          color: DealGoColors.primary.withValues(alpha: 0.5),
        ),
      ),
    );
    if (resolved == null || resolved.isEmpty) {
      return placeholder;
    }
    return DealGoNetworkImage(
      resolved,
      fit: BoxFit.cover,
      width: double.infinity,
      height: double.infinity,
      fallback: placeholder,
    );
  }
}

/// "Ưu đãi quanh bạn": one coupon card per store with a live offer.
class _OfferStrip extends StatelessWidget {
  const _OfferStrip({required this.stores, required this.onOpen});

  final List<FoodStoreSummary> stores;
  final ValueChanged<FoodStoreSummary> onOpen;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final textTheme = Theme.of(context).textTheme;
    return SizedBox(
      key: const Key('food-offers-strip'),
      height: 116,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: stores.length,
        separatorBuilder: (context, index) =>
            const SizedBox(width: DealGoSpacing.s12),
        itemBuilder: (context, index) {
          final store = stores[index];
          final offer = store.offers.first;
          return DealGoStaggerIn(
            index: index,
            child: DealGoPressScale(
              child: Material(
                color: DealGoColors.dangerSurface,
                borderRadius: BorderRadius.circular(DealGoRadius.button),
                clipBehavior: Clip.antiAlias,
                child: InkWell(
                  key: Key('food-offer-card-${store.id}'),
                  onTap: () {
                    DealGoHaptics.tap();
                    onOpen(store);
                  },
                  child: SizedBox(
                    width: 248,
                    child: Row(
                      children: [
                        SizedBox(
                          width: 84,
                          height: double.infinity,
                          child: _StoreCover(imageUrl: store.imageUrl),
                        ),
                        Expanded(
                          child: Padding(
                            padding: const EdgeInsets.all(DealGoSpacing.s8),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(
                                  storeOfferLabel(l10n, offer),
                                  style: textTheme.labelLarge?.copyWith(
                                    color: DealGoColors.danger,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  store.name,
                                  style: textTheme.bodySmall?.copyWith(
                                    color: DealGoColors.text,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                if (offer.minOrderVnd > 0) ...[
                                  const SizedBox(height: 2),
                                  Text(
                                    l10n.voucherMinOrder(
                                      formatVnd(offer.minOrderVnd),
                                    ),
                                    style: textTheme.labelSmall?.copyWith(
                                      color: DealGoColors.textSecondary,
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

/// "Đánh giá cao": compact store rows in a horizontal rail, so the whole
/// collection costs one strip of height instead of a stack of cards.
class _StoreStrip extends StatelessWidget {
  const _StoreStrip({
    required this.stores,
    required this.ratings,
    required this.onOpen,
    super.key,
  });

  static const _cardWidth = 288.0;

  /// Fits the tallest compact card at the default text scale; the rail grows
  /// with accessibility text scaling so the bounded meta lines never overflow.
  static const _railHeight = 128.0;

  final List<FoodStoreSummary> stores;
  final Map<String, StoreRating> ratings;
  final ValueChanged<FoodStoreSummary> onOpen;

  @override
  Widget build(BuildContext context) {
    final railHeight = MediaQuery.textScalerOf(context)
        .clamp(minScaleFactor: 1)
        .scale(_railHeight);
    return SizedBox(
      height: railHeight,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        clipBehavior: Clip.none,
        itemCount: stores.length,
        separatorBuilder: (context, index) =>
            const SizedBox(width: DealGoSpacing.s12),
        itemBuilder: (context, index) {
          final store = stores[index];
          return SizedBox(
            width: _cardWidth,
            child: DealGoStaggerIn(
              index: index,
              child: FoodStoreCard(
                key: Key('food-top-store-${store.id}'),
                store: store,
                rating: ratings[store.id],
                variant: FoodStoreCardVariant.compact,
                onTap: () => onOpen(store),
              ),
            ),
          );
        },
      ),
    );
  }
}

typedef _Dish = ({FoodStoreSummary store, FoodFeaturedItem item});

/// Photo band and width shared by the cards of a strip. The body grows to the
/// tallest card in the row so every card in a strip ends on the same line.
const double _dishCardWidth = 168;
const double _dishCardPhotoHeight = 112;

/// Horizontal dish cards ("Đang giảm giá", "Món mới"); a tap opens the store.
class _DishStrip extends StatelessWidget {
  const _DishStrip({required this.dishes, required this.onOpen, super.key});

  final List<_Dish> dishes;
  final ValueChanged<FoodStoreSummary> onOpen;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      clipBehavior: Clip.none,
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (final (index, dish) in dishes.indexed) ...[
              if (index > 0) const SizedBox(width: DealGoSpacing.s12),
              DealGoStaggerIn(
                index: index,
                child: _DishCard(dish: dish, onTap: () => onOpen(dish.store)),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _DishCard extends StatelessWidget {
  const _DishCard({required this.dish, required this.onTap});

  final _Dish dish;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final textTheme = Theme.of(context).textTheme;
    final item = dish.item;
    final storeName = dish.store.name;
    final original = item.originalPriceVnd;
    final discountPercent = original != null && original > item.priceVnd
        ? ((original - item.priceVnd) * 100 / original).round()
        : 0;
    final card = DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(DealGoRadius.button),
        boxShadow: DealGoShadows.card,
      ),
      child: Material(
        color: DealGoColors.card,
        borderRadius: BorderRadius.circular(DealGoRadius.button),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          key: Key('food-dish-card-${item.id}'),
          onTap: () {
            DealGoHaptics.tap();
            onTap();
          },
          child: SizedBox(
            width: _dishCardWidth,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SizedBox(
                  height: _dishCardPhotoHeight,
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      FoodThumb(
                        size: _dishCardWidth,
                        imageUrl: item.imageUrl,
                        placeholderAsset: foodDishFallbackImage(
                          dish.store.category,
                        ),
                      ),
                      if (item.isNew)
                        const Positioned(
                          left: DealGoSpacing.s8,
                          top: DealGoSpacing.s8,
                          child: FoodNewBadge(),
                        ),
                      // The saving reads as a badge on the photo, so the price
                      // block below stays the same height on every card.
                      if (discountPercent > 0)
                        Positioned(
                          right: DealGoSpacing.s8,
                          top: DealGoSpacing.s8,
                          child: FoodDiscountPill(percent: discountPercent),
                        ),
                    ],
                  ),
                ),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.all(DealGoSpacing.s8),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          item.name,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: textTheme.bodyMedium?.copyWith(
                            color: DealGoColors.text,
                            fontWeight: FontWeight.w700,
                            height: 1.3,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          storeName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: textTheme.labelSmall?.copyWith(
                            color: DealGoColors.textSecondary,
                          ),
                        ),
                        const Spacer(),
                        const SizedBox(height: DealGoSpacing.s4),
                        FoodPriceText(
                          priceVnd: item.priceVnd,
                          originalPriceVnd: item.originalPriceVnd,
                          size: 14,
                          showPercent: false,
                        ),
                        if (item.soldCount > 0) ...[
                          const SizedBox(height: 2),
                          Text(
                            l10n.foodItemSold(item.soldCount),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: textTheme.labelSmall?.copyWith(
                              color: DealGoColors.textTertiary,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
    return DealGoPressScale(child: card);
  }
}
