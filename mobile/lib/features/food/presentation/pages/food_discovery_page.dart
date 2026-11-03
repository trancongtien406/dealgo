import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/config/api_base_url.dart';
import '../../../../core/design_system/components/dealgo_chip.dart';
import '../../../../core/design_system/components/dealgo_state_view.dart';
import '../../../../core/design_system/components/dealgo_haptics.dart';
import '../../../../core/design_system/tokens/dealgo_tokens.dart';
import '../../../../core/design_system/tokens/dealgo_type_scale.dart';
import '../../../../core/motion/dealgo_motion_widgets.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../home_banner/presentation/home_banner_carousel.dart';
import '../../../identity/domain/entities/app_role.dart';
import '../../../identity/presentation/widgets/auth_widgets.dart';
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
import '../widgets/food_feed_footer.dart';
import '../widgets/store_meta.dart';
import '../../../../core/design_system/icons/dealgo_icons.dart';
import '../../../../core/design_system/components/dealgo_skeleton.dart';
import '../../../../core/design_system/components/dealgo_nav_insets.dart';
import '../../../../core/design_system/components/dealgo_network_image.dart';

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
    context.read<FoodDiscoveryCubit>().loadMore();
  }

  void _reload() {
    final origin = foodCartOrigin(context);
    context.read<FoodDiscoveryCubit>().load(
      currentAccessToken(context),
      lat: origin.lat,
      lng: origin.lng,
      sortBy: _filters.sortBy,
      maxKm: _filters.maxKm,
    );
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
    setState(() => _filters = next);
    _reload();
  }

  void _openStore(FoodStoreSummary store) {
    context.push(FoodRoutes.store(store.id));
  }

  void _scrollToStores() {
    final target = _storesKey.currentContext;
    if (target == null) {
      return;
    }
    final reduceMotion = MediaQuery.disableAnimationsOf(context);
    Scrollable.ensureVisible(
      target,
      duration: reduceMotion
          ? Duration.zero
          : const Duration(milliseconds: 280),
      curve: Curves.easeOut,
    );
  }

  @override
  Widget build(BuildContext context) {
    final discovery = context.watch<FoodDiscoveryCubit>().state;
    final ready = discovery is FoodDiscoveryReady ? discovery : null;
    final allStores = ready?.stores ?? const <FoodStoreSummary>[];
    final stores = [
      for (final store in allStores)
        if ((!_filters.openNow || store.openNow) &&
            (!_filters.offersOnly || store.offers.isNotEmpty))
          store,
    ];
    final fetched = ready?.ratings ?? const <String, StoreRating>{};
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
                      filterActive: !_filters.isDefault,
                    ),
                    if (refreshing) ...[
                      const SizedBox(height: DealGoSpacing.s8),
                      const LinearProgressIndicator(minHeight: 2),
                    ],
                    if (!_filters.isDefault) ...[
                      const SizedBox(height: DealGoSpacing.s8),
                      _ActiveFilterSummary(
                        filters: _filters,
                        onEdit: _openFilters,
                        onClear: () {
                          setState(() => _filters = const FoodFilters());
                          _reload();
                        },
                      ),
                    ],
                    const SizedBox(height: DealGoSpacing.s16),
                    HomeBannerCarousel(
                      role: AppRole.customer,
                      service: 'FOOD',
                      gapBelow: 0,
                      empty: _FoodBanner(onExplore: _scrollToStores),
                    ),
                    const SizedBox(height: DealGoSpacing.s16),
                    _CategoryStrip(
                      selected: null,
                      onSelected: (code) =>
                          context.push(FoodRoutes.categoryOf(code)),
                    ),
                    if (offerStores.isNotEmpty) ...[
                      const SizedBox(height: DealGoSpacing.s16),
                      _SectionHeader(
                        title: l10n.foodOffersNearTitle,
                        onSeeAll: () =>
                            context.push(FoodRoutes.categoryOf(null)),
                      ),
                      const SizedBox(height: DealGoSpacing.s12),
                      _OfferStrip(stores: offerStores, onOpen: _openStore),
                    ],
                    const SizedBox(height: DealGoSpacing.s20),
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
              SliverPadding(
                padding: EdgeInsets.fromLTRB(
                  gutter,
                  DealGoSpacing.s20,
                  gutter,
                  DealGoSpacing.s16 + cartRoom + bottomInset,
                ),
                sliver: SliverList.list(
                  children: [
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
                      for (final (index, store) in popular.indexed) ...[
                        DealGoStaggerIn(
                          index: index,
                          child: FoodStoreCard(
                            store: store,
                            rating: ratings[store.id],
                            variant: FoodStoreCardVariant.compact,
                            onTap: () => _openStore(store),
                          ),
                        ),
                        const SizedBox(height: DealGoSpacing.s12),
                      ],
                    ],
                  ],
                ),
              ),
            ],
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
  final rated = [
    for (final store in stores)
      if (ratings[store.id]?.average != null && store.closedReason == null)
        store,
  ]..sort((a, b) => ratings[b.id]!.average!.compareTo(ratings[a.id]!.average!));
  return rated.take(4).toList(growable: false);
}

class _DiscoveryHeader extends StatelessWidget {
  const _DiscoveryHeader({required this.onPickAddress});

  final VoidCallback onPickAddress;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const Expanded(child: DealGoWordmark()),
        _LocationChip(onTap: onPickAddress),
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
    return Material(
      color: DealGoColors.subtlePurple,
      shape: const CircleBorder(),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => context.go('/customer/account'),
        child: SizedBox(
          width: 36,
          height: 36,
          child: Icon(
            DealGoIcons.user,
            color: DealGoColors.primary,
            size: 20,
            semanticLabel: l10n.accountTitle,
          ),
        ),
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
    final address = context.select<FoodCartCubit, String>(
      (cart) => cart.state.dropoffLabel.trim(),
    );
    final chosen = address.isNotEmpty;
    final label = chosen ? address : l10n.foodDeliverTo;
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 150),
      child: Material(
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
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: chosen
                            ? DealGoColors.text
                            : DealGoColors.primary,
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
      ),
    );
  }
}

class _FoodBanner extends StatelessWidget {
  const _FoodBanner({required this.onExplore});

  final VoidCallback onExplore;

  @override
  Widget build(BuildContext context) {
    // Image-only, tappable — same rule as the Admin banners.
    return DealGoPressScale(
      child: Material(
        color: DealGoColors.primaryDeep,
        borderRadius: BorderRadius.circular(DealGoRadius.button),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          key: const Key('food-banner'),
          onTap: onExplore,
          child: SizedBox(
            height: 168,
            width: double.infinity,
            child: Image.asset(
              foodStoreCoverImage,
              fit: BoxFit.cover,
              errorBuilder: (context, error, stackTrace) =>
                  const SizedBox.shrink(),
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
          children: [
            avatar,
            const SizedBox(height: DealGoSpacing.s8),
            Text(
              label,
              textAlign: TextAlign.center,
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
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(
            color: DealGoColors.subtlePurple,
            shape: BoxShape.circle,
            border: selected == null
                ? Border.all(color: DealGoColors.primary, width: 1.5)
                : null,
          ),
          child: Image.asset(
            foodStoreCoverImage,
            fit: BoxFit.cover,
            errorBuilder: (context, error, stack) => const SizedBox.shrink(),
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
      height: 112,
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
    required this.filterActive,
  });

  final VoidCallback onOpenSearch;
  final VoidCallback onOpenFilters;
  final bool filterActive;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Row(
      children: [
        Expanded(
          child: InkWell(
            onTap: onOpenSearch,
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
                  borderRadius: BorderRadius.circular(DealGoRadius.button),
                  borderSide: BorderSide(color: DealGoColors.border),
                ),
              ),
              child: Text(
                l10n.foodDiscoverySearchHint,
                style: DealGoType.body(Theme.of(context).textTheme)
                    .copyWith(color: DealGoColors.textSecondary),
              ),
            ),
          ),
        ),
        const SizedBox(width: DealGoSpacing.s8),
        _FilterButton(active: filterActive, onTap: onOpenFilters),
      ],
    );
  }
}

class _FilterButton extends StatelessWidget {
  const _FilterButton({required this.active, required this.onTap});

  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Material(
      color: active ? DealGoColors.primary : DealGoColors.card,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(DealGoRadius.button),
        side: BorderSide(
          color: active ? DealGoColors.primary : DealGoColors.border,
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        key: const Key('food-discovery-filter'),
        onTap: onTap,
        child: Semantics(
          button: true,
          label: l10n.foodFilterButton,
          child: SizedBox(
            width: 52,
            height: 52,
            child: Icon(
              DealGoIcons.filter,
              color: active ? Colors.white : DealGoColors.primary,
            ),
          ),
        ),
      ),
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
    return Wrap(
      spacing: DealGoSpacing.s8,
      runSpacing: DealGoSpacing.s8,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        if (filters.sortBy == 'rating')
          DealGoChip(
            label: l10n.foodFilterRating,
            tone: DealGoChipTone.brand,
            selected: true,
            onTap: onEdit,
          ),
        if (km != null)
          DealGoChip(
            label: l10n.foodFilterKm(km),
            tone: DealGoChipTone.brand,
            selected: true,
            onTap: onEdit,
          ),
        if (filters.openNow)
          DealGoChip(
            label: l10n.foodFilterOpenNow,
            tone: DealGoChipTone.success,
            selected: true,
            onTap: onEdit,
          ),
        if (filters.offersOnly)
          DealGoChip(
            label: l10n.foodFilterOffers,
            tone: DealGoChipTone.promo,
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
    final placeholder = Image.asset(
      foodStoreCoverImage,
      fit: BoxFit.cover,
      width: double.infinity,
      height: double.infinity,
      errorBuilder: (context, error, stack) =>
          ColoredBox(color: DealGoColors.amberSurface),
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

typedef _Dish = ({FoodStoreSummary store, FoodFeaturedItem item});

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
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
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
            width: 156,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  height: 112,
                  width: double.infinity,
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      FoodThumb(
                        size: 156,
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
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(DealGoSpacing.s8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item.name,
                        style: textTheme.bodyMedium?.copyWith(
                          color: DealGoColors.text,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        dish.store.name,
                        style: textTheme.labelSmall?.copyWith(
                          color: DealGoColors.textSecondary,
                        ),
                      ),
                      const SizedBox(height: DealGoSpacing.s4),
                      FoodPriceText(
                        priceVnd: item.priceVnd,
                        originalPriceVnd: item.originalPriceVnd,
                        size: 14,
                      ),
                      if (item.soldCount > 0) ...[
                        const SizedBox(height: 2),
                        Text(
                          l10n.foodItemSold(item.soldCount),
                          style: textTheme.labelSmall?.copyWith(
                            color: DealGoColors.textTertiary,
                          ),
                        ),
                      ],
                    ],
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
