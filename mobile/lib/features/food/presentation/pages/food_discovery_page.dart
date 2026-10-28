import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/config/api_base_url.dart';
import '../../../../core/design_system/components/dealgo_state_view.dart';
import '../../../../core/design_system/components/dealgo_haptics.dart';
import '../../../../core/design_system/tokens/dealgo_tokens.dart';
import '../../../../core/motion/dealgo_motion_widgets.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../home_banner/presentation/home_banner_carousel.dart';
import '../../../identity/domain/entities/app_role.dart';
import '../../../identity/presentation/widgets/auth_widgets.dart';
import '../../../places/presentation/place_picker_page.dart';
import '../../../ride/presentation/cubit/ride_destination.dart';
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
import '../widgets/store_meta.dart';
import '../../../../core/design_system/icons/dealgo_icons.dart';
import '../../../../core/l10n/ui_message.dart';
import '../../../../core/design_system/components/dealgo_skeleton.dart';
import '../../../../core/design_system/components/dealgo_nav_insets.dart';
import '../../../../core/design_system/components/dealgo_network_image.dart';

class FoodDiscoveryPage extends StatelessWidget {
  const FoodDiscoveryPage({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) => FoodDiscoveryCubit(
        listFoodStores: context.read<ListFoodStores>(),
        ratings: context.read<RatingRepository>(),
        location: context.read<LocationService>(),
      )..load(currentAccessToken(context)),
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
  String? _category;

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  void _reload() {
    context.read<FoodDiscoveryCubit>().load(currentAccessToken(context));
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
    final stores = switch (discovery) {
      FoodDiscoveryReady(:final stores) => stores,
      _ => const <FoodStoreSummary>[],
    };
    final fetched = switch (discovery) {
      FoodDiscoveryReady(:final ratings) => ratings,
      _ => const <String, StoreRating>{},
    };
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
    final error = discovery is FoodDiscoveryFailed ? discovery.message : null;
    // One swipeable row on this page. The rest open from "Xem tất cả".
    final visible = stores.take(8).toList(growable: false);
    final popular = _popularThisWeek(stores, ratings);
    final cartRoom = FoodCartBar.showsFor(context.watch<FoodCartCubit>().state)
        ? kFoodCartBarRoom
        : 0.0;
    return Stack(
      children: [
        SafeArea(
          bottom: false,
          child: ListView(
            controller: _scroll,
            padding: dealGoScrollPadding(
              context,
              EdgeInsets.fromLTRB(
                DealGoDimensions.pageGutter,
                DealGoSpacing.s8,
                DealGoDimensions.pageGutter,
                DealGoSpacing.s16 + cartRoom,
              ),
            ),
            children: [
              const _DiscoveryHeader(),
              const SizedBox(height: DealGoSpacing.s16),
              InkWell(
                onTap: () => context.push(FoodRoutes.search),
                borderRadius: BorderRadius.circular(DealGoRadius.button),
                child: InputDecorator(
                  decoration: InputDecoration(
                    hintText: l10n.foodDiscoverySearchHint,
                    hintStyle: Theme.of(context).textTheme.bodyMedium
                        ?.copyWith(color: DealGoColors.textSecondary),
                    filled: true,
                    fillColor: DealGoColors.card,
                    prefixIcon: const Icon(
                      DealGoIcons.search,
                      color: DealGoColors.primary,
                    ),
                    suffixIcon: const Icon(
                      DealGoIcons.filter,
                      color: DealGoColors.primary,
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                      vertical: DealGoSpacing.s12,
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(DealGoRadius.button),
                      borderSide: const BorderSide(color: DealGoColors.border),
                    ),
                  ),
                  child: Text(
                    l10n.foodDiscoverySearchHint,
                    style: Theme.of(context).textTheme.bodyMedium
                        ?.copyWith(color: DealGoColors.textSecondary),
                  ),
                ),
              ),
              const SizedBox(height: DealGoSpacing.s16),
              HomeBannerCarousel(
                role: AppRole.customer,
                service: 'FOOD',
                gapBelow: 0,
                empty: _FoodBanner(onExplore: _scrollToStores),
              ),
              const SizedBox(height: DealGoSpacing.s16),
              _CategoryStrip(
                selected: _category,
                onSelected: (code) {
                  setState(() => _category = code);
                  context.push(FoodRoutes.categoryOf(code));
                },
              ),
              if (offerStores.isNotEmpty) ...[
                const SizedBox(height: DealGoSpacing.s16),
                _SectionHeader(
                  title: l10n.foodOffersNearTitle,
                  onSeeAll: () => context.push(FoodRoutes.categoryOf(null)),
                ),
                const SizedBox(height: DealGoSpacing.s12),
                _OfferStrip(stores: offerStores, onOpen: _openStore),
              ],
              const SizedBox(height: DealGoSpacing.s20),
              _SectionHeader(
                title: l10n.foodCollectionNear,
                onSeeAll: () => context.push(FoodRoutes.categoryOf(null)),
              ),
              const SizedBox(height: DealGoSpacing.s12),
              _StoreResults(
                key: _storesKey,
                loading: loading,
                error: error,
                stores: visible,
                ratings: ratings,
                onRetry: _reload,
                onOpen: _openStore,
              ),
              if (deals.isNotEmpty) ...[
                const SizedBox(height: DealGoSpacing.s20),
                _SectionHeader(
                  title: l10n.foodCollectionDeals,
                  onSeeAll: () => context.push(FoodRoutes.categoryOf(null)),
                ),
                const SizedBox(height: DealGoSpacing.s12),
                _DishStrip(
                  key: const Key('food-deals-strip'),
                  dishes: deals,
                  onOpen: _openStore,
                ),
              ],
              if (newDishes.isNotEmpty) ...[
                const SizedBox(height: DealGoSpacing.s20),
                _SectionHeader(
                  title: l10n.foodCollectionNewDishes,
                  onSeeAll: () => context.push(FoodRoutes.categoryOf(null)),
                ),
                const SizedBox(height: DealGoSpacing.s12),
                _DishStrip(
                  key: const Key('food-new-strip'),
                  dishes: newDishes,
                  onOpen: _openStore,
                ),
              ],
              if (popular.isNotEmpty) ...[
                const SizedBox(height: DealGoSpacing.s20),
                _SectionHeader(
                  title: l10n.foodCollectionTopRated,
                  onSeeAll: () => context.push(FoodRoutes.categoryOf(null)),
                ),
                const SizedBox(height: DealGoSpacing.s12),
                for (final (index, store) in popular.indexed) ...[
                  DealGoStaggerIn(
                    index: index,
                    child: _WideStoreCard(
                      store: store,
                      rating: ratings[store.id],
                      onTap: () => _openStore(store),
                    ),
                  ),
                  const SizedBox(height: DealGoSpacing.s12),
                ],
              ],
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
  const _DiscoveryHeader();

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const Expanded(child: DealGoWordmark()),
        const _LocationChip(),
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
  const _LocationChip();

  Future<void> _pick(BuildContext context) async {
    final place = await pickPlace(context, PlacePickPurpose.pickup);
    if (place == null || !context.mounted) {
      return;
    }
    context.read<RideDestinationCubit>().choose(place);
    context.go('/customer/book');
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Material(
      color: DealGoColors.card,
      shape: const StadiumBorder(side: BorderSide(color: DealGoColors.border)),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => _pick(context),
        child: Semantics(
          button: true,
          label: l10n.homeCitySample,
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
                const SizedBox(width: 2),
                Text(
                  l10n.homeCitySample,
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: DealGoColors.text,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const Icon(
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

class _StoreResults extends StatelessWidget {
  const _StoreResults({
    required this.loading,
    required this.error,
    required this.stores,
    required this.ratings,
    required this.onRetry,
    required this.onOpen,
    super.key,
  });

  final bool loading;
  final UiMessage? error;
  final List<FoodStoreSummary> stores;
  final Map<String, StoreRating> ratings;
  final VoidCallback onRetry;
  final ValueChanged<FoodStoreSummary> onOpen;

  @override
  Widget build(BuildContext context) {
    if (loading) {
      return const DealGoSkeletonList(
        itemCount: 4,
        padding: EdgeInsets.symmetric(vertical: DealGoSpacing.s8),
      );
    }
    final l10n = AppLocalizations.of(context);
    final message = error?.resolve(l10n);
    if (message != null) {
      return DealGoStateView.failure(
        context,
        onRetry: onRetry,
        cause: error?.error,
        message: message,
      );
    }
    if (stores.isEmpty) {
      return DealGoStateView(
        art: DealGoStateArt.noSearch,
        title: l10n.emptyStoresNearby,
        message: l10n.emptyStoresNearbyBody,
        compact: true,
      );
    }
    // Bleeds to the screen edge so the next card peeks in.
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      clipBehavior: Clip.none,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (final (index, store) in stores.indexed) ...[
            if (index > 0) const SizedBox(width: DealGoSpacing.s12),
            SizedBox(
              width: 236,
              child: DealGoStaggerIn(
                index: index,
                child: _StoreTile(
                  key: Key('food-store-card-${store.id}'),
                  store: store,
                  rating: ratings[store.id],
                  onTap: () => onOpen(store),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _StoreTile extends StatelessWidget {
  const _StoreTile({
    required this.store,
    required this.onTap,
    this.rating,
    super.key,
  });

  final FoodStoreSummary store;
  final StoreRating? rating;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final card = DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(DealGoRadius.button),
        boxShadow: DealGoShadows.card,
      ),
      child: Material(
        color: DealGoColors.card,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(DealGoRadius.button),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () {
            DealGoHaptics.tap();
            onTap();
          },
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              AspectRatio(
                aspectRatio: 2,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    _StoreCover(imageUrl: store.imageUrl),
                    if (store.offers.isNotEmpty)
                      Positioned(
                        left: DealGoSpacing.s8,
                        top: DealGoSpacing.s8,
                        child: StoreOfferBadge(
                          key: Key('food-store-offer-${store.id}'),
                          offer: store.offers.first,
                          compact: true,
                        ),
                      ),
                    if (store.logoUrl != null)
                      Positioned(
                        left: DealGoSpacing.s8,
                        bottom: DealGoSpacing.s8,
                        child: _StoreLogo(url: store.logoUrl!),
                      ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(DealGoSpacing.s12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      store.name,
                      style: Theme.of(context).textTheme.titleMedium
                          ?.copyWith(fontSize: 15),
                    ),
                    const SizedBox(height: DealGoSpacing.s4),
                    StoreMetaLine(store: store, rating: rating),
                    if (store.minOrderVnd > 0) ...[
                      const SizedBox(height: DealGoSpacing.s8),
                      FoodStoreBadges(store: store, showOffer: false),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
    return DealGoPressScale(child: card);
  }
}

class _WideStoreCard extends StatelessWidget {
  const _WideStoreCard({required this.store, required this.onTap, this.rating});

  final FoodStoreSummary store;
  final StoreRating? rating;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final card = DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(DealGoRadius.button),
        boxShadow: DealGoShadows.card,
      ),
      child: Material(
        color: DealGoColors.card,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(DealGoRadius.button),
          side: const BorderSide(color: DealGoColors.border),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () {
            DealGoHaptics.tap();
            onTap();
          },
          child: Padding(
            padding: const EdgeInsets.all(DealGoSpacing.s12),
            child: Row(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(DealGoRadius.input),
                  child: SizedBox(
                    width: 84,
                    height: 84,
                    child: _StoreCover(imageUrl: store.imageUrl),
                  ),
                ),
                const SizedBox(width: DealGoSpacing.s12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        store.name,
                        style: textTheme.titleMedium?.copyWith(fontSize: 16),
                      ),
                      const SizedBox(height: DealGoSpacing.s4),
                      StoreMetaLine(store: store, rating: rating),
                      if (store.offers.isNotEmpty || store.minOrderVnd > 0) ...[
                        const SizedBox(height: DealGoSpacing.s8),
                        FoodStoreBadges(store: store),
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
          const ColoredBox(color: DealGoColors.amberSurface),
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

class _StoreLogo extends StatelessWidget {
  const _StoreLogo({required this.url});

  final String url;

  @override
  Widget build(BuildContext context) {
    final resolved = resolveMediaUrl(url);
    if (resolved == null || resolved.isEmpty) return const SizedBox.shrink();
    return Container(
      width: 32,
      height: 32,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: DealGoColors.card,
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white, width: 2),
      ),
      child: DealGoNetworkImage(
        resolved,
        fit: BoxFit.cover,
        fallback: const SizedBox.shrink(),
      ),
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
