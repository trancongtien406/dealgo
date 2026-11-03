import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:geolocator/geolocator.dart';

import '../../../../core/config/api_base_url.dart';
import '../../../../core/location/location_service.dart';
import '../../../../core/maps/map_lat_lng.dart';
import '../../../../core/maps/map_markers.dart';
import '../../../../core/maps/map_port.dart';
import '../../../../core/network/api_exception.dart';
import '../../../../core/design_system/components/dealgo_banner.dart';
import '../../../../core/design_system/components/dealgo_nav_insets.dart';
import '../../../../core/motion/dealgo_sheet.dart';
import '../../../../core/design_system/components/dealgo_skeleton.dart';
import '../../../../core/design_system/components/dealgo_voucher_ticket.dart';
import '../../../../core/design_system/components/dealgo_state_view.dart';
import '../../../../core/network/request_failure.dart';
import '../../../../core/design_system/tokens/dealgo_tokens.dart';
import '../../../../core/motion/dealgo_motion_widgets.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../places/domain/place.dart' show foldVietnamese;
import '../../domain/entities/food_models.dart';
import '../../domain/entities/food_money.dart';
import '../../domain/usecases/get_food_store.dart';
import '../cubit/food_cart_cubit.dart';
import 'food_item_options_page.dart';
import '../cubit/food_store_cubit.dart';
import '../widgets/food_widgets.dart';
import '../widgets/food_badges.dart';
import '../widgets/food_dish_gallery.dart';
import '../widgets/food_category_tile.dart';
import '../food_categories_store.dart';
import '../widgets/food_cart_bar.dart';
import '../widgets/store_meta.dart';
import '../utils/food_maps.dart';
import '../../../driver_card/presentation/driver_card_tile.dart'
    show formatRatingAverage;
import '../../../rating/domain/service_rating.dart';
import '../../../rating/presentation/rate_service_card.dart';

import 'package:intl/intl.dart';

import '../../../../core/design_system/icons/dealgo_icons.dart';
import '../../../../core/l10n/api_error_text.dart';
import '../../../../core/design_system/components/dealgo_app_header.dart';
import '../../../../core/design_system/components/dealgo_network_image.dart';

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

/// Pinned bar geometry: tabs always, then the in-store search.
const double _tabsHeight = 46;
const double _searchHeight = 54;

/// Width of a menu row's photo; it spans the row's full height.
const double _menuImageWidth = 112;

/// Narrower photo inside the category rail layout, where the list shares the
/// width with the rail.
const double _menuCompactImageWidth = 88;

/// Vertical category list beside the menu items.
const double _menuRailWidth = 108;

class _FoodStorePageState extends State<_FoodStoreView> {
  final TextEditingController _query = TextEditingController();
  FoodStoreDetail? _store;
  StoreReviews? _reviews;
  StoreReviews? _filtered;
  int? _reviewStars;
  var _reviewsBusy = false;
  var _loading = true;
  Object? _failure;
  var _tab = _StoreTab.menu;
  double? _distanceKm;

  @override
  void initState() {
    super.initState();
    _query.addListener(() => setState(() {}));
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  @override
  void dispose() {
    _query.dispose();
    super.dispose();
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
      unawaited(_locate(store));
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

  /// Straight-line distance from the chosen delivery address, falling back to
  /// the device fix when no address has been picked yet.
  Future<void> _locate(FoodStoreDetail store) async {
    final lat = store.lat;
    final lng = store.lng;
    if (lat == null || lng == null) return;
    final dropoff = context.read<FoodCartCubit>().state;
    var originLat = dropoff.dropoffLat;
    var originLng = dropoff.dropoffLng;
    if (originLat == null || originLng == null) {
      try {
        final position = await context
            .read<LocationService>()
            .quietPosition()
            .timeout(const Duration(seconds: 5));
        if (position == null) return;
        originLat = position.latitude;
        originLng = position.longitude;
      } on Object {
        return;
      }
    }
    if (!mounted) return;
    final km =
        Geolocator.distanceBetween(originLat, originLng, lat, lng) / 1000;
    setState(() => _distanceKm = km);
    context.read<FoodCartCubit>().setStoreDistance(widget.storeId, km);
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

  Future<void> _filterReviews(int? stars) async {
    final token = currentAccessToken(context);
    if (token == null) return;
    setState(() {
      _reviewStars = stars;
      _filtered = null;
      _reviewsBusy = stars != null;
    });
    if (stars == null) return;
    try {
      final page = await context.read<RatingRepository>().storeReviews(
        accessToken: token,
        storeId: widget.storeId,
        stars: stars,
      );
      if (mounted && _reviewStars == stars) {
        setState(() {
          _filtered = page;
          _reviewsBusy = false;
        });
      }
    } on Object {
      if (mounted) setState(() => _reviewsBusy = false);
    }
  }

  Future<void> _moreReviews() async {
    final token = currentAccessToken(context);
    final current = _reviewStars == null ? _reviews : _filtered;
    if (token == null || current == null || _reviewsBusy) return;
    setState(() => _reviewsBusy = true);
    try {
      final next = await context.read<RatingRepository>().storeReviews(
        accessToken: token,
        storeId: widget.storeId,
        page: current.page + 1,
        stars: _reviewStars,
      );
      if (!mounted) return;
      final merged = StoreReviews(
        summary: current.summary,
        items: [...current.items, ...next.items],
        page: next.page,
        hasMore: next.hasMore,
      );
      setState(() {
        if (_reviewStars == null) {
          _reviews = merged;
        } else {
          _filtered = merged;
        }
        _reviewsBusy = false;
      });
    } on Object {
      if (mounted) setState(() => _reviewsBusy = false);
    }
  }

  List<_MenuGroup> _groups(FoodStoreDetail store, AppLocalizations l10n) {
    final query = foldVietnamese(_query.text.trim());
    bool matches(FoodMenuItem item) =>
        query.isEmpty ||
        foldVietnamese(item.name).contains(query) ||
        foldVietnamese(item.description ?? '').contains(query);
    final items = [
      for (final item in store.items)
        if (matches(item)) item,
    ];
    if (query.isNotEmpty) {
      return [if (items.isNotEmpty) _MenuGroup('search', null, items)];
    }
    final known = {for (final section in store.menuSections) section.id};
    final best = [
      for (final item in items)
        if (item.soldCount > 0 && item.available) item,
    ]..sort((a, b) => b.soldCount.compareTo(a.soldCount));
    return [
      if (best.length >= 2 && store.menuSections.isNotEmpty)
        _MenuGroup('best', l10n.foodStoreBestsellers, best.take(3).toList()),
      for (final section in store.menuSections)
        if (items.where((i) => i.menuCategoryId == section.id).toList()
            case final list when list.isNotEmpty)
          _MenuGroup(section.id, section.name, list),
      if (items.where((i) => !known.contains(i.menuCategoryId)).toList()
          case final rest when rest.isNotEmpty)
        _MenuGroup(
          'other',
          store.menuSections.isEmpty ? null : l10n.foodStoreSectionOther,
          rest,
        ),
    ];
  }

  Future<void> _openMaps(FoodStoreDetail store) async {
    final l10n = AppLocalizations.of(context);
    final opened = await openStoreInGoogleMaps(store);
    if (opened || !mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(l10n.foodStoreMapOpenFailed)));
  }

  void _openReviews() {
    setState(() => _tab = _StoreTab.reviews);
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
                  : _storeBody(context, store, l10n),
            ),
          ],
        ),
      ),
      bottomNavigationBar: store == null
          ? null
          : FoodCartBar(storeId: store.id, offers: store.offers),
    );
  }

  Widget _storeBody(
    BuildContext context,
    FoodStoreDetail store,
    AppLocalizations l10n,
  ) {
    const gutter = EdgeInsets.symmetric(
      horizontal: DealGoDimensions.pageGutter,
    );
    final groups = _groups(store, l10n);
    final sections = [
      for (final group in groups)
        if (group.title != null) group,
    ];
    final showSearch = _tab == _StoreTab.menu;
    final showRail = showSearch && sections.length > 1;
    final pinned = _tabsHeight + (showSearch ? _searchHeight : 0);
    final rating = _reviews?.summary;
    return NestedScrollView(
      headerSliverBuilder: (context, _) => [
        SliverPadding(
          padding: gutter,
          sliver: SliverList.list(
            children: [
              _Hero(store: store),
              const SizedBox(height: DealGoSpacing.s16),
              _StoreHeading(
                store: store,
                rating: rating,
                reviews: _reviews,
                distanceKm: _distanceKm,
                onRatingTap: _openReviews,
                onOpenMaps: () => _openMaps(store),
              ),
              if (store.offers.isNotEmpty) ...[
                const SizedBox(height: DealGoSpacing.s16),
                _StoreOffers(offers: store.offers, storeId: store.id),
              ],
              const SizedBox(height: DealGoSpacing.s12),
            ],
          ),
        ),
        SliverPersistentHeader(
          pinned: true,
          delegate: _PinnedHeader(
            height: pinned,
            child: Column(
              children: [
                Padding(
                  padding: gutter,
                  child: _Tabs(
                    selected: _tab,
                    reviewCount: rating?.count,
                    onSelected: (tab) => setState(() => _tab = tab),
                  ),
                ),
                if (showSearch)
                  SizedBox(
                    height: _searchHeight,
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(
                        DealGoDimensions.pageGutter,
                        DealGoSpacing.s4,
                        DealGoDimensions.pageGutter,
                        DealGoSpacing.s6,
                      ),
                      child: _MenuSearchBar(controller: _query),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ],
      body: switch (_tab) {
        _StoreTab.menu =>
          showRail
              ? _MenuBoard(
                  key: const ValueKey('menu'),
                  store: store,
                  sections: sections,
                )
              : _MenuList(
                  key: const ValueKey('menu'),
                  store: store,
                  groups: groups,
                  searching: _query.text.trim().isNotEmpty,
                ),
        _StoreTab.reviews => _ScrollBody(
          key: const ValueKey('reviews'),
          child: _Reviews(
            reviews: _reviews,
            filtered: _reviewStars == null ? _reviews : _filtered,
            stars: _reviewStars,
            busy: _reviewsBusy,
            onFilter: _filterReviews,
            onMore: _moreReviews,
          ),
        ),
        _StoreTab.info => _ScrollBody(
          key: const ValueKey('info'),
          child: _StoreInfo(store: store, onOpenMaps: () => _openMaps(store)),
        ),
      },
    );
  }
}

enum _StoreTab { menu, reviews, info }

class _MenuGroup {
  const _MenuGroup(this.id, this.title, this.items);

  final String id;

  /// Null = no heading (single unnamed list or search results).
  final String? title;
  final List<FoodMenuItem> items;
}

class _PinnedHeader extends SliverPersistentHeaderDelegate {
  _PinnedHeader({required this.height, required this.child});

  final double height;
  final Widget child;

  @override
  double get minExtent => height;

  @override
  double get maxExtent => height;

  @override
  Widget build(
    BuildContext context,
    double shrinkOffset,
    bool overlapsContent,
  ) {
    return Material(
      color: DealGoColors.canvas,
      elevation: overlapsContent || shrinkOffset > 0 ? 1 : 0,
      shadowColor: DealGoColors.border,
      child: child,
    );
  }

  @override
  bool shouldRebuild(_PinnedHeader oldDelegate) => true;
}

class _Hero extends StatelessWidget {
  const _Hero({required this.store});

  final FoodStoreDetail store;

  @override
  Widget build(BuildContext context) {
    final gallery = <String>[
      for (final item in store.items)
        if ((item.imageUrl ?? '').isNotEmpty) item.imageUrl!,
    ];
    // Merchant cover photo; without one, the first dish photo, then the logo.
    final cover =
        store.coverUrl ?? (gallery.isNotEmpty ? gallery.first : store.logoUrl);
    final logo = resolveMediaUrl(store.logoUrl);
    return Stack(
      clipBehavior: Clip.none,
      children: [
        FoodCoverImage(
          key: const Key('food-store-cover'),
          imageUrl: cover,
          aspectRatio: 2,
          placeholderAsset: foodStoreCoverImage,
        ),
        if (logo != null && logo.isNotEmpty)
          Positioned(
            left: DealGoSpacing.s12,
            bottom: DealGoSpacing.s12,
            child: Container(
              key: const Key('food-store-logo'),
              width: 56,
              height: 56,
              clipBehavior: Clip.antiAlias,
              decoration: BoxDecoration(
                color: DealGoColors.card,
                borderRadius: BorderRadius.circular(DealGoRadius.input),
                border: Border.all(color: Colors.white, width: 2),
                boxShadow: DealGoShadows.card,
              ),
              child: DealGoNetworkImage(
                logo,
                fit: BoxFit.cover,
                fallback: const SizedBox.shrink(),
              ),
            ),
          ),
      ],
    );
  }
}

class _StoreHeading extends StatelessWidget {
  const _StoreHeading({
    required this.store,
    required this.onRatingTap,
    required this.onOpenMaps,
    this.rating,
    this.reviews,
    this.distanceKm,
  });

  final VoidCallback onOpenMaps;
  final FoodStoreDetail store;
  final StoreRating? rating;
  final StoreReviews? reviews;
  final double? distanceKm;
  final VoidCallback onRatingTap;

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
    final prep = store.estimatedPrepMinutes;
    final distance = distanceKm;
    // Same estimate as the list: prep + 3 min per km.
    final eta = prep != null && distance != null
        ? prep + (distance * 3).round()
        : null;
    final category = foodCategoryLabel(context, store.category);
    final ratingText = storeRatingText(context, rating);
    final address = store.addressLabel?.trim() ?? '';
    final sold = store.items.fold<int>(0, (sum, item) => sum + item.soldCount);
    final tags = _praisedTags(reviews);
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
        if (category != null) ...[
          const SizedBox(height: 2),
          Text(category, style: textTheme.bodySmall),
        ],
        if (store.description != null) ...[
          const SizedBox(height: DealGoSpacing.s6),
          Text(
            store.description!,
            key: const Key('food-store-description'),
            style: textTheme.bodyMedium?.copyWith(
              color: DealGoColors.textSecondary,
            ),
          ),
        ],
        if (address.isNotEmpty) ...[
          const SizedBox(height: DealGoSpacing.s6),
          InkWell(
            key: const Key('food-store-address-link'),
            onTap: onOpenMaps,
            borderRadius: BorderRadius.circular(DealGoRadius.input),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 2),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.only(top: 1),
                    child: Icon(
                      DealGoIcons.pin,
                      size: 14,
                      color: DealGoColors.textSecondary,
                    ),
                  ),
                  const SizedBox(width: DealGoSpacing.s4),
                  Expanded(
                    child: Text(
                      address,
                      key: const Key('food-store-address'),
                      style: textTheme.bodySmall,
                    ),
                  ),
                  const SizedBox(width: DealGoSpacing.s4),
                  Text(
                    l10n.foodStoreDirections,
                    style: textTheme.labelSmall?.copyWith(
                      color: DealGoColors.primary,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  Icon(
                    DealGoIcons.navigation,
                    size: 13,
                    color: DealGoColors.primary,
                  ),
                ],
              ),
            ),
          ),
        ],
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
        const SizedBox(height: DealGoSpacing.s12),
        Wrap(
          spacing: DealGoSpacing.s8,
          runSpacing: DealGoSpacing.s8,
          children: [
            if (ratingText != null)
              InkWell(
                key: const Key('food-store-rating'),
                onTap: onRatingTap,
                borderRadius: BorderRadius.circular(DealGoRadius.pill),
                child: FoodInfoChip(
                  label: ratingText,
                  icon: DealGoIcons.star,
                  iconColor: DealGoColors.amber,
                ),
              ),
            if (distance != null)
              Tooltip(
                message: l10n.foodStoreOpenInMaps,
                child: InkWell(
                  key: const Key('food-store-distance'),
                  onTap: onOpenMaps,
                  borderRadius: BorderRadius.circular(DealGoRadius.pill),
                  child: FoodInfoChip(
                    label: formatDistanceKm(context, distance),
                    icon: DealGoIcons.navigation,
                  ),
                ),
              ),
            if (store.openNow && prep != null)
              FoodInfoChip(
                key: const Key('food-store-prep-estimate'),
                label: l10n.foodStorePrepChip(eta ?? prep),
                icon: DealGoIcons.motorbike,
                filled: true,
              ),
            if (sold > 0)
              FoodInfoChip(
                key: const Key('food-store-sold'),
                label: l10n.foodStoreSoldTotal(sold),
                icon: DealGoIcons.trending,
              ),
            if (store.minOrderVnd > 0)
              FoodMinOrderPill(
                key: const Key('food-store-min-order'),
                amountVnd: store.minOrderVnd,
              ),
          ],
        ),
        if (store.schedule.hoursConfigured) ...[
          const SizedBox(height: DealGoSpacing.s8),
          Row(
            children: [
              Icon(
                DealGoIcons.clock,
                size: 14,
                color: DealGoColors.textSecondary,
              ),
              const SizedBox(width: DealGoSpacing.s4),
              Expanded(
                child: Text(
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
              ),
            ],
          ),
        ],
        if (tags.isNotEmpty) ...[
          const SizedBox(height: DealGoSpacing.s12),
          Wrap(
            key: const Key('food-store-tags'),
            spacing: DealGoSpacing.s6,
            runSpacing: DealGoSpacing.s6,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Text(
                l10n.foodStoreTagsTitle,
                style: textTheme.labelSmall?.copyWith(
                  color: DealGoColors.textSecondary,
                  fontWeight: FontWeight.w700,
                ),
              ),
              for (final (tag, count) in tags)
                FoodPill(
                  label: '${ratingTagLabel(l10n, tag)} · $count',
                  foreground: DealGoColors.brandGreen,
                  background: DealGoColors.greenSurface,
                ),
            ],
          ),
        ],
      ],
    );
  }
}

/// Store position on the map; tapping anywhere (or the pill) opens Google Maps.
class _StoreMapCard extends StatelessWidget {
  const _StoreMapCard({
    required this.store,
    required this.onOpenMaps,
    this.height = 160,
  });

  final FoodStoreDetail store;
  final VoidCallback onOpenMaps;
  final double height;

  @override
  Widget build(BuildContext context) {
    final lat = store.lat;
    final lng = store.lng;
    if (lat == null || lng == null) return const SizedBox.shrink();
    final l10n = AppLocalizations.of(context);
    final textTheme = Theme.of(context).textTheme;
    final center = MapLatLng(lat: lat, lng: lng);
    final radius = BorderRadius.circular(DealGoRadius.card);
    return Semantics(
      button: true,
      label: l10n.foodStoreOpenInMaps,
      child: GestureDetector(
        onTap: onOpenMaps,
        child: ClipRRect(
          borderRadius: radius,
          child: SizedBox(
            key: const Key('food-store-map'),
            height: height,
            width: double.infinity,
            child: Stack(
              fit: StackFit.expand,
              children: [
                context.watch<MapPort>().buildMap(
                  center: center,
                  markers: [center],
                  stopStyle: MapStopStyle.food,
                  fitPadding: const EdgeInsets.all(44),
                ),
                Positioned(
                  left: DealGoSpacing.s8,
                  right: DealGoSpacing.s8,
                  bottom: DealGoSpacing.s8,
                  child: Material(
                    color: DealGoColors.card,
                    borderRadius: BorderRadius.circular(DealGoRadius.input),
                    elevation: 2,
                    shadowColor: DealGoColors.border,
                    clipBehavior: Clip.antiAlias,
                    child: InkWell(
                      key: const Key('food-store-map-open'),
                      onTap: onOpenMaps,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: DealGoSpacing.s12,
                          vertical: DealGoSpacing.s8,
                        ),
                        child: Row(
                          children: [
                            const Icon(
                              DealGoIcons.pin,
                              size: 16,
                              color: DealGoColors.primary,
                            ),
                            const SizedBox(width: DealGoSpacing.s6),
                            Expanded(
                              child: Text(
                                store.addressLabel?.trim().isNotEmpty == true
                                    ? store.addressLabel!
                                    : l10n.foodStoreOpenInMaps,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: textTheme.bodySmall?.copyWith(
                                  color: DealGoColors.text,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                            const SizedBox(width: DealGoSpacing.s8),
                            Text(
                              l10n.foodStoreDirections,
                              style: textTheme.labelSmall?.copyWith(
                                color: DealGoColors.primary,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            const Icon(
                              DealGoIcons.chevronRight,
                              size: 16,
                              color: DealGoColors.primary,
                            ),
                          ],
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

/// Address-only location block for stores the merchant has not pinned yet:
/// customers still need a way to see where the store is and open directions.
class _StoreLocationCard extends StatelessWidget {
  const _StoreLocationCard({required this.address, required this.onOpenMaps});

  final String address;
  final VoidCallback onOpenMaps;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final textTheme = Theme.of(context).textTheme;
    return Material(
      color: DealGoColors.subtlePurple,
      borderRadius: BorderRadius.circular(DealGoRadius.card),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        key: const Key('food-store-map'),
        onTap: onOpenMaps,
        child: Padding(
          padding: const EdgeInsets.all(DealGoSpacing.s12),
          child: Row(
            children: [
              const Icon(
                DealGoIcons.pin,
                size: 18,
                color: DealGoColors.primary,
              ),
              const SizedBox(width: DealGoSpacing.s8),
              Expanded(
                child: Text(
                  address,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: textTheme.bodySmall?.copyWith(
                    color: DealGoColors.text,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              const SizedBox(width: DealGoSpacing.s8),
              Text(
                l10n.foodStoreDirections,
                style: textTheme.labelSmall?.copyWith(
                  color: DealGoColors.primary,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const Icon(
                DealGoIcons.chevronRight,
                size: 16,
                color: DealGoColors.primary,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Positive tags repeated in the loaded reviews, most mentioned first.
List<(RatingTag, int)> _praisedTags(StoreReviews? reviews) {
  if (reviews == null) return const [];
  final counts = <RatingTag, int>{};
  for (final review in reviews.items) {
    for (final tag in review.tags) {
      if (tag.positive) counts[tag] = (counts[tag] ?? 0) + 1;
    }
  }
  final ranked = [
    for (final entry in counts.entries)
      if (entry.value >= 2) (entry.key, entry.value),
  ]..sort((a, b) => b.$2.compareTo(a.$2));
  return ranked.take(3).toList(growable: false);
}

/// The store's live offers as voucher tickets: a swipeable strip, and
/// "Xem tất cả" for the full list in a sheet. "Dùng" attaches the code to
/// this store's cart; checkout prices it again.
class _StoreOffers extends StatelessWidget {
  const _StoreOffers({required this.offers, required this.storeId});

  final List<StoreOffer> offers;
  final String storeId;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final textTheme = Theme.of(context).textTheme;
    return Column(
      key: const Key('food-store-offers'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                l10n.foodStoreOffersTitle,
                style: textTheme.titleMedium,
              ),
            ),
            if (offers.length > 1)
              TextButton(
                key: const Key('food-store-offers-all'),
                onPressed: () => showDealGoSheet<void>(
                  context: context,
                  isScrollControlled: true,
                  builder: (_) => BlocProvider.value(
                    value: context.read<FoodCartCubit>(),
                    child: _StoreOffersSheet(offers: offers),
                  ),
                ),
                child: Text(l10n.actionSeeAll),
              ),
          ],
        ),
        const SizedBox(height: DealGoSpacing.s8),
        // Natural height: every ticket grows to its tallest sibling, never clips.
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          clipBehavior: Clip.none,
          child: IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (final (index, offer) in offers.indexed) ...[
                  if (index > 0) const SizedBox(width: DealGoSpacing.s12),
                  DealGoStaggerIn(
                    index: index,
                    child: SizedBox(
                      width: 300,
                      child: _OfferTicket(offer: offer),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _StoreOffersSheet extends StatelessWidget {
  const _StoreOffersSheet({required this.offers});

  final List<StoreOffer> offers;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return SafeArea(
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(context).height * 0.8,
        ),
        child: Column(
          key: const Key('food-store-offers-sheet'),
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(
                DealGoDimensions.pageGutter,
                DealGoSpacing.s16,
                DealGoDimensions.pageGutter,
                DealGoSpacing.s8,
              ),
              child: Text(
                l10n.foodStoreOffersTitle,
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ),
            Flexible(
              child: ListView.separated(
                shrinkWrap: true,
                padding: const EdgeInsets.fromLTRB(
                  DealGoDimensions.pageGutter,
                  DealGoSpacing.s8,
                  DealGoDimensions.pageGutter,
                  DealGoSpacing.s24,
                ),
                itemCount: offers.length,
                separatorBuilder: (_, _) =>
                    const SizedBox(height: DealGoSpacing.s12),
                itemBuilder: (context, index) => DealGoStaggerIn(
                  index: index,
                  child: _OfferTicket(offer: offers[index], inSheet: true),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _OfferTicket extends StatelessWidget {
  const _OfferTicket({required this.offer, this.inSheet = false});

  final StoreOffer offer;
  final bool inSheet;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final used = context.select<FoodCartCubit, bool>(
      (cart) => cart.state.voucherCode == offer.code,
    );
    final prefix = inSheet ? 'food-store-sheet-offer' : 'food-store-offer';
    return DealGoVoucherTicket(
      key: Key('$prefix-${offer.id}'),
      headline: storeOfferHeadline(l10n, offer),
      caption: offer.code,
      title: offer.name,
      conditions: storeOfferConditions(
        l10n,
        offer,
        locale: Localizations.localeOf(context).toLanguageTag(),
      ),
      highlighted: used,
      action: used
          ? DealGoTicketButton(
              key: Key('$prefix-used-${offer.id}'),
              label: l10n.voucherUsed,
              accent: DealGoColors.danger,
              done: true,
            )
          : DealGoTicketButton(
              key: Key('$prefix-use-${offer.id}'),
              label: l10n.foodStoreOfferUse,
              accent: DealGoColors.danger,
              onPressed: () {
                context.read<FoodCartCubit>().applyVoucher(code: offer.code);
                ScaffoldMessenger.of(context)
                  ..hideCurrentSnackBar()
                  ..showSnackBar(
                    SnackBar(
                      content: Text(l10n.foodStoreOfferApplied(offer.code)),
                    ),
                  );
              },
            ),
    );
  }
}

class _Tabs extends StatelessWidget {
  const _Tabs({
    required this.selected,
    required this.onSelected,
    this.reviewCount,
  });

  final _StoreTab selected;
  final ValueChanged<_StoreTab> onSelected;
  final int? reviewCount;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final count = reviewCount;
    final tabs = <(_StoreTab, String)>[
      (_StoreTab.menu, l10n.foodStoreTabMenu),
      (
        _StoreTab.reviews,
        count != null && count > 0
            ? '${l10n.foodStoreTabReviews} ($count)'
            : l10n.foodStoreTabReviews,
      ),
      (_StoreTab.info, l10n.foodStoreTabInfo),
    ];
    return DecoratedBox(
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: DealGoColors.border)),
      ),
      child: SizedBox(
        height: _tabsHeight,
        child: Row(
          children: [
            for (final tab in tabs)
              Expanded(
                child: InkWell(
                  key: Key('food-store-tab-${tab.$1.name}'),
                  onTap: () => onSelected(tab.$1),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    alignment: Alignment.center,
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
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        tab.$2,
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
      ),
    );
  }
}

class _MenuSearchBar extends StatelessWidget {
  const _MenuSearchBar({required this.controller});

  final TextEditingController controller;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final textTheme = Theme.of(context).textTheme;
    final border = OutlineInputBorder(
      borderRadius: BorderRadius.circular(DealGoRadius.button),
      borderSide: BorderSide(color: DealGoColors.border),
    );
    return TextField(
      key: const Key('food-store-search'),
      controller: controller,
      textInputAction: TextInputAction.search,
      style: textTheme.bodyMedium,
      decoration: InputDecoration(
        hintText: l10n.foodStoreSearchMenu,
        hintStyle: textTheme.bodySmall?.copyWith(
          color: DealGoColors.textSecondary,
        ),
        prefixIcon: const Icon(
          DealGoIcons.search,
          size: 18,
          color: DealGoColors.primary,
        ),
        prefixIconConstraints: const BoxConstraints(
          minWidth: 38,
          minHeight: 38,
        ),
        suffixIcon: controller.text.isEmpty
            ? null
            : IconButton(
                key: const Key('food-store-search-clear'),
                tooltip: MaterialLocalizations.of(context).deleteButtonTooltip,
                onPressed: controller.clear,
                icon: const Icon(DealGoIcons.close, size: 16),
              ),
        suffixIconConstraints: const BoxConstraints(
          minWidth: 38,
          minHeight: 38,
        ),
        filled: true,
        fillColor: DealGoColors.card,
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(vertical: 11),
        border: border,
        enabledBorder: border,
        focusedBorder: border.copyWith(
          borderSide: const BorderSide(color: DealGoColors.primary),
        ),
      ),
    );
  }
}

/// Vertical category index beside the menu items. The active row follows the
/// items being scrolled and is kept inside the rail.
class _CategoryRail extends StatefulWidget {
  const _CategoryRail({
    required this.sections,
    required this.activeId,
    required this.onSelected,
  });

  final List<_MenuGroup> sections;
  final String activeId;
  final ValueChanged<String> onSelected;

  @override
  State<_CategoryRail> createState() => _CategoryRailState();
}

class _CategoryRailState extends State<_CategoryRail> {
  final ScrollController _scroll = ScrollController();
  final Map<String, GlobalKey> _keys = {};

  @override
  void didUpdateWidget(_CategoryRail oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.activeId != widget.activeId) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _revealActive());
    }
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  void _revealActive() {
    if (!mounted || !_scroll.hasClients) return;
    final row = _keys[widget.activeId]?.currentContext?.findRenderObject();
    final viewport = _scroll.position.context.storageContext.findRenderObject();
    if (row is! RenderBox || viewport is! RenderBox) return;
    final top = row.localToGlobal(Offset.zero, ancestor: viewport).dy;
    final bottom = top + row.size.height;
    const margin = DealGoSpacing.s24;
    double? target;
    if (top < margin) {
      target = _scroll.offset + top - margin;
    } else if (bottom > viewport.size.height - margin) {
      target = _scroll.offset + bottom - viewport.size.height + margin;
    }
    if (target == null) return;
    _scroll.animateTo(
      target.clamp(0, _scroll.position.maxScrollExtent),
      duration: MediaQuery.disableAnimationsOf(context)
          ? Duration.zero
          : const Duration(milliseconds: 220),
      curve: Curves.easeOutCubic,
    );
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final l10n = AppLocalizations.of(context);
    return Semantics(
      label: l10n.foodStoreMenuSections,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: DealGoColors.canvas,
          border: Border(right: BorderSide(color: DealGoColors.divider)),
        ),
        child: ListView.builder(
          key: const Key('food-menu-categories'),
          controller: _scroll,
          padding: EdgeInsets.only(
            top: DealGoSpacing.s4,
            bottom:
                DealGoSpacing.s24 +
                kFoodCartBarRoom +
                MediaQuery.paddingOf(context).bottom,
          ),
          itemCount: widget.sections.length,
          itemBuilder: (context, index) {
            final section = widget.sections[index];
            final active = section.id == widget.activeId;
            return KeyedSubtree(
              key: _keys.putIfAbsent(section.id, GlobalKey.new),
              child: Material(
                color: active ? DealGoColors.card : Colors.transparent,
                child: InkWell(
                  key: Key('food-menu-category-${section.id}'),
                  onTap: () => widget.onSelected(section.id),
                  child: Container(
                    decoration: BoxDecoration(
                      border: Border(
                        left: BorderSide(
                          color: active
                              ? DealGoColors.primary
                              : Colors.transparent,
                          width: 3,
                        ),
                      ),
                    ),
                    padding: const EdgeInsets.fromLTRB(
                      DealGoSpacing.s12,
                      DealGoSpacing.s12,
                      DealGoSpacing.s8,
                      DealGoSpacing.s12,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          section.title!,
                          key: Key('food-menu-category-label-${section.id}'),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: textTheme.bodySmall?.copyWith(
                            fontSize: 13,
                            height: 1.25,
                            color: active
                                ? DealGoColors.primary
                                : DealGoColors.textSecondary,
                            fontWeight: active
                                ? FontWeight.w700
                                : FontWeight.w500,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          l10n.foodStoreSectionCount(section.items.length),
                          style: textTheme.labelSmall?.copyWith(
                            fontSize: 11,
                            color: active
                                ? DealGoColors.primary
                                : DealGoColors.textTertiary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

/// Category rail on the left, the whole menu on the right: tapping a category
/// scrolls the items to it, and scrolling highlights the category in view.
class _MenuBoard extends StatefulWidget {
  const _MenuBoard({required this.store, required this.sections, super.key});

  final FoodStoreDetail store;
  final List<_MenuGroup> sections;

  @override
  State<_MenuBoard> createState() => _MenuBoardState();
}

class _MenuBoardState extends State<_MenuBoard> {
  final Map<String, GlobalKey> _sectionKeys = {};
  late String _activeId = widget.sections.first.id;
  ScrollController? _scroll;
  var _jumping = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Inside the store's NestedScrollView this is the inner controller, so a
    // drag here still collapses the store header first.
    final controller = PrimaryScrollController.maybeOf(context);
    if (identical(controller, _scroll)) return;
    _scroll?.removeListener(_syncActiveSection);
    _scroll = controller;
    _scroll?.addListener(_syncActiveSection);
  }

  @override
  void dispose() {
    _scroll?.removeListener(_syncActiveSection);
    super.dispose();
  }

  void _jumpTo(String id) {
    final scroll = _scroll;
    setState(() {
      _activeId = id;
      _jumping = true;
    });
    final target = _sectionKeys[id]?.currentContext?.findRenderObject();
    if (scroll == null || !scroll.hasClients) {
      _jumping = false;
      return;
    }
    final offset = target == null
        ? scroll.position.maxScrollExtent
        : RenderAbstractViewport.of(target).getOffsetToReveal(target, 0).offset;
    final to = offset.clamp(0.0, scroll.position.maxScrollExtent);
    if (MediaQuery.disableAnimationsOf(context)) {
      scroll.jumpTo(to);
      _jumping = false;
    } else {
      scroll
          .animateTo(
            to,
            duration: const Duration(milliseconds: 320),
            curve: Curves.easeOutCubic,
          )
          .whenComplete(() => _jumping = false);
    }
  }

  void _syncActiveSection() {
    final scroll = _scroll;
    if (!mounted || _jumping || scroll == null || !scroll.hasClients) return;
    final position = scroll.position;
    final threshold = position.pixels + 12;
    String? active;
    for (final section in widget.sections) {
      final target = _sectionKeys[section.id]?.currentContext
          ?.findRenderObject();
      if (target == null) continue;
      final offset = RenderAbstractViewport.of(target)
          .getOffsetToReveal(target, 0)
          .offset;
      if (offset <= threshold) active = section.id;
    }
    if (position.pixels >= position.maxScrollExtent - 1) {
      active = widget.sections.last.id;
    }
    if (active != null && active != _activeId) {
      setState(() => _activeId = active!);
    }
  }

  @override
  Widget build(BuildContext context) {
    final store = widget.store;
    final l10n = AppLocalizations.of(context);
    final textTheme = Theme.of(context).textTheme;
    final best = foodBestSellerIds(store.items);
    final rows = <Widget>[];
    var index = 0;
    for (final section in widget.sections) {
      rows
        ..add(
          Padding(
            key: _sectionKeys.putIfAbsent(section.id, GlobalKey.new),
            padding: const EdgeInsets.only(
              top: DealGoSpacing.s4,
              bottom: DealGoSpacing.s8,
              left: 2,
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Expanded(
                  child: Text(
                    section.title!,
                    key: Key('food-menu-section-${section.id}'),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                const SizedBox(width: DealGoSpacing.s8),
                Text(
                  l10n.foodStoreSectionCount(section.items.length),
                  style: textTheme.labelSmall?.copyWith(
                    color: DealGoColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
        )
        ..addAll([
          for (final item in section.items) ...[
            DealGoStaggerIn(
              index: index++,
              child: _MenuItem(
                key: Key('food-menu-${section.id}-${item.id}'),
                store: store,
                item: item,
                featured: section.id == 'best',
                bestSeller: best.contains(item.id),
                compact: true,
              ),
            ),
            const SizedBox(height: DealGoSpacing.s12),
          ],
        ]);
    }
    return Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SizedBox(
          width: _menuRailWidth,
          child: _CategoryRail(
            sections: widget.sections,
            activeId: _activeId,
            onSelected: _jumpTo,
          ),
        ),
        Expanded(
          // Built eagerly so a rail tap can scroll to any section, including
          // ones still below the fold.
          child: SingleChildScrollView(
            key: const Key('food-menu-items'),
            controller: _scroll,
            padding: dealGoScrollPadding(
              context,
              const EdgeInsets.fromLTRB(
                DealGoSpacing.s8,
                DealGoSpacing.s12,
                DealGoDimensions.pageGutter,
                DealGoSpacing.s24 + kFoodCartBarRoom,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: rows,
            ),
          ),
        ),
      ],
    );
  }
}

/// One flat list: in-store search results, or a store whose menu has a single
/// unnamed section.
class _MenuList extends StatelessWidget {
  const _MenuList({
    required this.store,
    required this.groups,
    required this.searching,
    super.key,
  });

  final FoodStoreDetail store;
  final List<_MenuGroup> groups;
  final bool searching;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final textTheme = Theme.of(context).textTheme;
    final best = foodBestSellerIds(store.items);
    final padding = dealGoScrollPadding(
      context,
      const EdgeInsets.fromLTRB(
        DealGoDimensions.pageGutter,
        DealGoSpacing.s12,
        DealGoDimensions.pageGutter,
        DealGoSpacing.s24 + kFoodCartBarRoom,
      ),
    );
    if (store.items.isEmpty) {
      return ListView(
        padding: padding,
        children: [FoodPanel(child: Text(l10n.foodStoreNoItems))],
      );
    }
    if (groups.isEmpty) {
      return ListView(
        padding: padding,
        children: [
          FoodPanel(
            key: const Key('food-store-search-empty'),
            child: Text(l10n.foodStoreSearchNone),
          ),
        ],
      );
    }
    final rows = <Widget>[];
    var index = 0;
    for (final group in groups) {
      if (group.title != null || !searching) {
        rows.add(
          Padding(
            padding: const EdgeInsets.only(
              top: DealGoSpacing.s4,
              bottom: DealGoSpacing.s8,
              left: 2,
            ),
            child: Text(
              group.title == null
                  ? l10n.foodStoreMenuCount(group.items.length)
                  : '${group.title} (${group.items.length})',
              style: textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        );
      }
      for (final item in group.items) {
        rows
          ..add(
            DealGoStaggerIn(
              index: index++,
              child: _MenuItem(
                key: Key('food-menu-${group.id}-${item.id}'),
                store: store,
                item: item,
                featured: group.id == 'best',
                bestSeller: best.contains(item.id),
              ),
            ),
          )
          ..add(const SizedBox(height: DealGoSpacing.s12));
      }
    }
    return ListView(padding: padding, children: rows);
  }
}

/// Scrolling page for the tab bodies that are laid out as one column.
class _ScrollBody extends StatelessWidget {
  const _ScrollBody({required this.child, super.key});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: dealGoScrollPadding(
        context,
        const EdgeInsets.fromLTRB(
          DealGoDimensions.pageGutter,
          DealGoSpacing.s12,
          DealGoDimensions.pageGutter,
          DealGoSpacing.s24 + kFoodCartBarRoom,
        ),
      ),
      children: [child],
    );
  }
}

void _showClosedHint(BuildContext context, FoodStoreDetail store) {
  final l10n = AppLocalizations.of(context);
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(
        content: Text(
          store.closedReason == StoreClosedReason.closed
              ? l10n.foodStoreClosedBanner
              : l10n.foodStorePausedBanner,
        ),
      ),
    );
}

class _MenuItem extends StatelessWidget {
  const _MenuItem({
    required this.store,
    required this.item,
    this.featured = false,
    this.bestSeller = false,
    this.compact = false,
    super.key,
  });

  final FoodStoreDetail store;
  final FoodMenuItem item;
  final bool bestSeller;

  /// Copy in the best-sellers group: its own add key and no hero flight.
  final bool featured;

  /// Narrow row beside the category rail: smaller photo, type and controls.
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final l10n = AppLocalizations.of(context);
    final description = item.description?.trim();
    final radius = BorderRadius.circular(DealGoRadius.card);
    final closed = !store.canOrder;
    final photoWidth = compact ? _menuCompactImageWidth : _menuImageWidth;
    final inset = compact ? DealGoSpacing.s8 : DealGoSpacing.s12;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: DealGoColors.card,
        borderRadius: radius,
        border: Border.all(color: DealGoColors.border),
        boxShadow: DealGoShadows.card,
      ),
      child: ClipRRect(
        borderRadius: radius,
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            key: Key('food-dish-${item.id}'),
            onTap: item.available
                ? () {
                    if (closed) {
                      _showClosedHint(context, store);
                      return;
                    }
                    openFoodItemOptions(
                      context: context,
                      store: store,
                      item: item,
                    );
                  }
                : null,
            child: Stack(
              children: [
                Padding(
                  padding: EdgeInsets.fromLTRB(
                    inset,
                    inset,
                    photoWidth + (compact ? DealGoSpacing.s6 : inset),
                    inset,
                  ),
                  child: ConstrainedBox(
                    constraints: BoxConstraints(minHeight: compact ? 104 : 92),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              item.name,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: textTheme.titleMedium?.copyWith(
                                fontSize: compact ? 14 : 15,
                                height: 1.25,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            if (item.isNew || bestSeller) ...[
                              const SizedBox(height: DealGoSpacing.s4),
                              FoodItemBadges(
                                isNew: item.isNew,
                                bestSeller: bestSeller,
                              ),
                            ],
                            if (description != null &&
                                description.isNotEmpty) ...[
                              const SizedBox(height: DealGoSpacing.s4),
                              Text(
                                description,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: textTheme.bodySmall?.copyWith(
                                  color: DealGoColors.textSecondary,
                                ),
                              ),
                            ],
                            if (item.soldCount > 0 ||
                                item.prepMinutes != null) ...[
                              const SizedBox(height: DealGoSpacing.s4),
                              if (compact)
                                Text(
                                  [
                                    if (item.soldCount > 0)
                                      l10n.foodItemSold(item.soldCount),
                                    if (item.prepMinutes != null)
                                      l10n.foodStorePrepChip(item.prepMinutes!),
                                  ].join(' · '),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: textTheme.labelSmall?.copyWith(
                                    color: DealGoColors.textSecondary,
                                  ),
                                )
                              else
                                Wrap(
                                  spacing: DealGoSpacing.s8,
                                  runSpacing: 2,
                                  crossAxisAlignment: WrapCrossAlignment.center,
                                  children: [
                                    if (item.soldCount > 0)
                                      _ItemMeta(
                                        icon: DealGoIcons.trending,
                                        label: l10n.foodItemSold(
                                          item.soldCount,
                                        ),
                                      ),
                                    if (item.prepMinutes != null)
                                      _ItemMeta(
                                        icon: DealGoIcons.clock,
                                        label: l10n.foodStorePrepChip(
                                          item.prepMinutes!,
                                        ),
                                      ),
                                  ],
                                ),
                            ],
                          ],
                        ),
                        Padding(
                          padding: const EdgeInsets.only(top: DealGoSpacing.s8),
                          child: Row(
                            children: [
                              Expanded(
                                child: FoodPriceText(
                                  key: Key('food-price-${item.id}'),
                                  priceVnd: item.priceVnd,
                                  originalPriceVnd: item.originalPriceVnd,
                                  size: compact ? 14 : 16,
                                ),
                              ),
                              if (!item.available)
                                Text(
                                  l10n.foodItemSoldOut,
                                  style: textTheme.labelSmall?.copyWith(
                                    color: DealGoColors.danger,
                                    fontWeight: FontWeight.w700,
                                  ),
                                )
                              else if (closed)
                                Text(
                                  store.closedReason == StoreClosedReason.closed
                                      ? l10n.foodStoreClosedLabel
                                      : l10n.foodStorePaused,
                                  style: textTheme.labelSmall?.copyWith(
                                    color: DealGoColors.danger,
                                    fontWeight: FontWeight.w700,
                                  ),
                                )
                              else
                                _MenuAddControl(
                                  store: store,
                                  item: item,
                                  compact: compact,
                                  keyPrefix: featured
                                      ? 'food-best-add'
                                      : 'food-add',
                                ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                Positioned(
                  top: 0,
                  right: 0,
                  bottom: 0,
                  width: photoWidth,
                  child: KeyedSubtree(
                    key: Key('food-menu-photo-${item.id}'),
                    child: _photo(context, l10n),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// Full-height dish photo; only items that open the options page fly it.
  Widget _photo(BuildContext context, AppLocalizations l10n) {
    final resolved = resolveMediaUrl(item.imageUrl);
    final photoCount = foodDishGalleryImages(
      imageUrls: item.imageUrls,
      fallbackImageUrl: item.imageUrl,
    ).length;
    final placeholder = Image.asset(
      foodDishFallbackImage(store.category),
      fit: BoxFit.cover,
      width: double.infinity,
      height: double.infinity,
      errorBuilder: (context, error, stack) =>
          ColoredBox(color: DealGoColors.amberSurface),
    );
    final Widget image = resolved == null || resolved.isEmpty
        ? placeholder
        : DealGoNetworkImage(
            resolved,
            fit: BoxFit.cover,
            fallback: placeholder,
          );
    return Stack(
      fit: StackFit.expand,
      children: [
        if (item.optionGroups.isEmpty || featured)
          image
        else
          DealGoHero(tag: foodItemHeroTag(item.id), child: image),
        if (!item.available)
          ColoredBox(
            color: Colors.white.withValues(alpha: 0.55),
            child: Center(
              child: FoodPill(
                label: l10n.foodItemSoldOut,
                foreground: DealGoColors.danger,
                background: DealGoColors.dangerSurface,
              ),
            ),
          ),
        if (photoCount > 1)
          Positioned(
            top: DealGoSpacing.s6,
            right: DealGoSpacing.s6,
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: DealGoColors.scrim,
                borderRadius: BorderRadius.circular(DealGoRadius.pill),
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: DealGoSpacing.s6,
                  vertical: DealGoSpacing.s2,
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      DealGoIcons.image,
                      size: 11,
                      color: Colors.white,
                    ),
                    const SizedBox(width: DealGoSpacing.s2),
                    Text(
                      '$photoCount',
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class _ItemMeta extends StatelessWidget {
  const _ItemMeta({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 12, color: DealGoColors.textTertiary),
        const SizedBox(width: 3),
        Text(
          label,
          style: Theme.of(context).textTheme.labelSmall
              ?.copyWith(color: DealGoColors.textSecondary),
        ),
      ],
    );
  }
}

/// Compact add / stepper: a 34pt circle instead of the default 48pt button so
/// the photo and price keep their room.
class _MenuAddControl extends StatelessWidget {
  const _MenuAddControl({
    required this.store,
    required this.item,
    this.compact = false,
    this.keyPrefix = 'food-add',
  });

  final FoodStoreDetail store;
  final FoodMenuItem item;
  final bool compact;
  final String keyPrefix;

  @override
  Widget build(BuildContext context) {
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
    final l10n = AppLocalizations.of(context);
    final addSize = compact ? 30.0 : 34.0;
    if (quantity == 0) {
      if (item.optionGroups.isNotEmpty && !compact) {
        return SizedBox(
          height: 32,
          child: TextButton.icon(
            key: Key('$keyPrefix-${item.id}'),
            onPressed: () =>
                openFoodItemOptions(context: context, store: store, item: item),
            style: TextButton.styleFrom(
              foregroundColor: DealGoColors.primary,
              backgroundColor: DealGoColors.subtlePurple,
              padding: const EdgeInsets.symmetric(horizontal: DealGoSpacing.s8),
              minimumSize: const Size(0, 32),
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              shape: const StadiumBorder(),
            ),
            icon: const Icon(DealGoIcons.add, size: 15),
            label: Text(
              l10n.foodItemOptionsChoose,
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
            ),
          ),
        );
      }
      return Tooltip(
        message: item.optionGroups.isNotEmpty
            ? l10n.foodItemOptionsChoose
            : l10n.foodAddToCart,
        child: SizedBox(
          width: addSize,
          height: addSize,
          child: Material(
            color: DealGoColors.primary,
            shape: const CircleBorder(),
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              key: Key('$keyPrefix-${item.id}'),
              onTap: () =>
                  quickAddFoodItem(context: context, store: store, item: item),
              child: Icon(
                DealGoIcons.add,
                size: compact ? 18 : 20,
                color: Colors.white,
              ),
            ),
          ),
        ),
      );
    }
    final cart = context.read<FoodCartCubit>();
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _StepButton(
          icon: DealGoIcons.remove,
          tooltip: l10n.foodDecreaseQuantity,
          size: compact ? 26 : 30,
          onPressed: () => cart.adjustCatalogQuantity(item.id, -1),
        ),
        SizedBox(
          width: compact ? 20 : 24,
          child: Text(
            '$quantity',
            textAlign: TextAlign.center,
            style:
                (compact
                        ? Theme.of(context).textTheme.labelMedium
                        : Theme.of(context).textTheme.titleSmall)
                    ?.copyWith(fontWeight: FontWeight.w800),
          ),
        ),
        _StepButton(
          key: Key('$keyPrefix-${item.id}'),
          icon: DealGoIcons.add,
          tooltip: l10n.foodAddToCart,
          size: compact ? 26 : 30,
          onPressed: quantity >= foodLineQuantityMax
              ? null
              : () => quickAddFoodItem(
                  context: context,
                  store: store,
                  item: item,
                ),
        ),
      ],
    );
  }
}

class _StepButton extends StatelessWidget {
  const _StepButton({
    required this.icon,
    required this.tooltip,
    required this.onPressed,
    this.size = 30,
    super.key,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback? onPressed;
  final double size;

  @override
  Widget build(BuildContext context) {
    final enabled = onPressed != null;
    return Tooltip(
      message: tooltip,
      child: SizedBox(
        width: size,
        height: size,
        child: Material(
          color: enabled ? DealGoColors.primary : DealGoColors.divider,
          shape: const CircleBorder(),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: onPressed,
            child: Icon(
              icon,
              size: size < 30 ? 16 : 18,
              color: enabled ? Colors.white : DealGoColors.textSecondary,
            ),
          ),
        ),
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
  const _Reviews({
    required this.reviews,
    required this.filtered,
    required this.stars,
    required this.busy,
    required this.onFilter,
    required this.onMore,
  });

  /// Unfiltered first page: carries the summary.
  final StoreReviews? reviews;

  /// What the list shows: [reviews] or the star-filtered pages.
  final StoreReviews? filtered;
  final int? stars;
  final bool busy;
  final ValueChanged<int?> onFilter;
  final VoidCallback onMore;

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
    final distribution = summary.distribution;
    final total = distribution?.fold<int>(0, (sum, n) => sum + n) ?? 0;
    final list = filtered;
    final dateFormat = DateFormat('dd/MM/yyyy');
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        FoodPanel(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              if (average != null) ...[
                Column(
                  children: [
                    Text(
                      formatRatingAverage(context, average),
                      style: textTheme.displaySmall?.copyWith(
                        fontWeight: FontWeight.w800,
                        color: DealGoColors.text,
                      ),
                    ),
                    _Stars(value: average.round(), size: 14),
                  ],
                ),
                const SizedBox(width: DealGoSpacing.s16),
              ] else ...[
                const Icon(DealGoIcons.starFilled, color: DealGoColors.amber),
                const SizedBox(width: DealGoSpacing.s8),
              ],
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
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
                    if (distribution != null && total > 0) ...[
                      const SizedBox(height: DealGoSpacing.s8),
                      for (var star = 5; star >= 1; star--)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 3),
                          child: Row(
                            children: [
                              SizedBox(
                                width: 14,
                                child: Text(
                                  '$star',
                                  style: textTheme.labelSmall,
                                ),
                              ),
                              const Icon(
                                DealGoIcons.starFilled,
                                size: 10,
                                color: DealGoColors.amber,
                              ),
                              const SizedBox(width: DealGoSpacing.s6),
                              Expanded(
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(4),
                                  child: TweenAnimationBuilder<double>(
                                    tween: Tween(
                                      begin: 0,
                                      end: distribution.length >= star
                                          ? distribution[star - 1] / total
                                          : 0,
                                    ),
                                    duration: const Duration(milliseconds: 420),
                                    curve: Curves.easeOutCubic,
                                    builder: (context, value, _) =>
                                        LinearProgressIndicator(
                                          key: Key('food-review-bar-$star'),
                                          value: value,
                                          minHeight: 6,
                                          color: DealGoColors.amber,
                                          backgroundColor: DealGoColors.divider,
                                        ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
        if (data.items.isNotEmpty || stars != null) ...[
          const SizedBox(height: DealGoSpacing.s12),
          Wrap(
            spacing: DealGoSpacing.s8,
            runSpacing: DealGoSpacing.s8,
            children: [
              for (final value in <int?>[null, 5, 4, 3, 2, 1])
                ChoiceChip(
                  key: Key('food-review-filter-${value ?? 'all'}'),
                  label: Text(
                    value == null
                        ? l10n.foodStoreReviewsAll
                        : l10n.rateStarTooltip(value),
                  ),
                  selected: stars == value,
                  showCheckmark: false,
                  onSelected: (_) => onFilter(value),
                  selectedColor: DealGoColors.subtlePurple,
                  visualDensity: VisualDensity.compact,
                ),
            ],
          ),
        ],
        if (list == null && busy)
          const Padding(
            padding: EdgeInsets.only(top: DealGoSpacing.s12),
            child: DealGoSkeletonList(itemCount: 2, padding: EdgeInsets.zero),
          )
        else if (list != null && list.items.isEmpty && stars != null)
          Padding(
            padding: const EdgeInsets.only(top: DealGoSpacing.s12),
            child: FoodPanel(child: Text(l10n.foodStoreReviewsFilterNone)),
          ),
        for (final (index, review)
            in (list?.items ?? const <StoreReview>[]).indexed) ...[
          const SizedBox(height: DealGoSpacing.s12),
          DealGoStaggerIn(
            index: index,
            child: FoodPanel(
              key: Key('food-review-${review.id.isEmpty ? index : review.id}'),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      _Stars(value: review.stars, size: 14),
                      const Spacer(),
                      Text(
                        dateFormat.format(review.createdAt),
                        style: textTheme.labelSmall?.copyWith(
                          color: DealGoColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                  if (review.tags.isNotEmpty) ...[
                    const SizedBox(height: DealGoSpacing.s8),
                    Wrap(
                      spacing: DealGoSpacing.s6,
                      runSpacing: DealGoSpacing.s6,
                      children: [
                        for (final tag in review.tags)
                          FoodInfoChip(label: ratingTagLabel(l10n, tag)),
                      ],
                    ),
                  ],
                  if (review.comment != null) ...[
                    const SizedBox(height: DealGoSpacing.s8),
                    Text(review.comment!, style: textTheme.bodyMedium),
                  ],
                  if (review.merchantReply != null) ...[
                    const SizedBox(height: DealGoSpacing.s8),
                    Container(
                      key: Key('food-review-reply-${review.id}'),
                      width: double.infinity,
                      padding: const EdgeInsets.all(DealGoSpacing.s12),
                      decoration: BoxDecoration(
                        color: DealGoColors.lavender,
                        borderRadius: BorderRadius.circular(DealGoRadius.input),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            l10n.foodStoreMerchantReply,
                            style: textTheme.labelMedium?.copyWith(
                              color: DealGoColors.primary,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: DealGoSpacing.s4),
                          Text(
                            review.merchantReply!,
                            style: textTheme.bodySmall?.copyWith(
                              color: DealGoColors.text,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
        if (list != null && list.hasMore) ...[
          const SizedBox(height: DealGoSpacing.s12),
          Center(
            child: OutlinedButton(
              key: const Key('food-reviews-more'),
              onPressed: busy ? null : onMore,
              child: Text(l10n.foodStoreReviewsMore),
            ),
          ),
        ],
      ],
    );
  }
}

class _Stars extends StatelessWidget {
  const _Stars({required this.value, this.size = 14});

  final int value;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var i = 0; i < 5; i++)
          Icon(
            DealGoIcons.starFilled,
            size: size,
            color: i < value ? DealGoColors.amber : DealGoColors.border,
          ),
      ],
    );
  }
}

class _StoreInfo extends StatelessWidget {
  const _StoreInfo({required this.store, required this.onOpenMaps});

  final FoodStoreDetail store;
  final VoidCallback onOpenMaps;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final textTheme = Theme.of(context).textTheme;
    final category = foodCategoryLabel(context, store.category);
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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (store.hasLocation) ...[
          _StoreMapCard(store: store, onOpenMaps: onOpenMaps, height: 200),
          const SizedBox(height: DealGoSpacing.s12),
        ] else if (store.addressLabel?.trim().isNotEmpty == true) ...[
          _StoreLocationCard(
            address: store.addressLabel!.trim(),
            onOpenMaps: onOpenMaps,
          ),
          const SizedBox(height: DealGoSpacing.s12),
        ],
        FoodPanel(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              row(DealGoIcons.store, l10n.foodStoreInfoName, store.name),
              if (store.description != null)
                row(DealGoIcons.info, l10n.foodStoreAbout, store.description!),
              if (category != null)
                row(
                  DealGoIcons.restaurant,
                  l10n.foodStoreInfoCategory,
                  category,
                ),
              row(
                DealGoIcons.pin,
                l10n.foodStoreInfoAddress,
                store.addressLabel ?? l10n.foodStoreInfoAddressMissing,
              ),
              if (store.schedule.hoursConfigured)
                row(
                  DealGoIcons.clock,
                  l10n.foodStoreInfoHours,
                  [
                    for (var day = 1; day <= 7; day++)
                      '${_dayShort(l10n, day)}  ${switch (store.schedule.day(day)) {
                        final hours? => '${hours.opensAt} – ${hours.closesAt}',
                        null => l10n.merchantHoursClosed,
                      }}',
                  ].join('\n'),
                ),
              if (store.estimatedPrepMinutes != null)
                row(
                  DealGoIcons.timer,
                  l10n.foodStoreInfoPrep,
                  l10n.foodStorePrepChip(store.estimatedPrepMinutes!),
                ),
              row(
                DealGoIcons.shoppingBag,
                l10n.foodStoreInfoMinOrder,
                store.minOrderVnd > 0
                    ? formatVnd(store.minOrderVnd)
                    : l10n.foodStoreInfoNoMinOrder,
              ),
              row(
                DealGoIcons.wallet,
                l10n.foodStoreInfoPayment,
                l10n.foodStoreInfoPaymentCod,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

String _dayShort(AppLocalizations l10n, int weekday) => switch (weekday) {
  1 => l10n.dayShortMon,
  2 => l10n.dayShortTue,
  3 => l10n.dayShortWed,
  4 => l10n.dayShortThu,
  5 => l10n.dayShortFri,
  6 => l10n.dayShortSat,
  _ => l10n.dayShortSun,
};
