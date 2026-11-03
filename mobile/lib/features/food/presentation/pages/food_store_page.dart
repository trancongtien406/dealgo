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

part 'store/store_hero.dart';
part 'store/store_map.dart';
part 'store/store_offers.dart';
part 'store/store_menu_nav.dart';
part 'store/store_menu_board.dart';
part 'store/store_menu_item.dart';
part 'store/store_reviews.dart';
part 'store/store_info.dart';

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

/// How long the detail read waits for a position before going out without one.
const Duration _preReadLocationWait = Duration(milliseconds: 1500);

/// Upper bound for the location read on the post-load distance path.
const Duration _locationWait = Duration(seconds: 5);

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
      // The store read needs the origin for the server-side "from" fee, but a
      // slow fix must not hold the page empty: after this cap the read goes
      // out without coordinates and the fee stays null.
      final origin = await _customerOrigin(timeout: _preReadLocationWait);
      if (!mounted) {
        return;
      }
      final store = await context.read<FoodStoreCubit>().load(
        accessToken: token,
        storeId: widget.storeId,
        lat: origin?.lat,
        lng: origin?.lng,
      );
      if (!mounted) {
        return;
      }
      setState(() {
        _store = store;
        _loading = false;
      });
      unawaited(_loadReviews(token));
      _locate(store, origin);
      if (origin == null) {
        unawaited(_locateAfterLoad(store));
      }
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

  /// Chosen delivery address first, then the device fix; null when neither is
  /// available (no distance, no quoted "from" fee).
  Future<({double lat, double lng})?> _customerOrigin({
    Duration timeout = _locationWait,
  }) async {
    final dropoff = context.read<FoodCartCubit>().state;
    final dropoffLat = dropoff.dropoffLat;
    final dropoffLng = dropoff.dropoffLng;
    if (dropoffLat != null && dropoffLng != null) {
      return (lat: dropoffLat, lng: dropoffLng);
    }
    try {
      final position = await context
          .read<LocationService>()
          .quietPosition()
          .timeout(timeout);
      if (position == null) return null;
      return (lat: position.latitude, lng: position.longitude);
    } on Object {
      return null;
    }
  }

  /// The pre-read cap may have expired; this second, longer attempt only fills
  /// the distance the page can still show without refetching the store.
  Future<void> _locateAfterLoad(FoodStoreDetail store) async {
    final origin = await _customerOrigin();
    if (!mounted || origin == null) return;
    _locate(store, origin);
  }

  /// Straight-line distance from [origin] to the store, when both are known.
  void _locate(FoodStoreDetail store, ({double lat, double lng})? origin) {
    final lat = store.lat;
    final lng = store.lng;
    if (lat == null || lng == null || origin == null) return;
    final km =
        Geolocator.distanceBetween(origin.lat, origin.lng, lat, lng) / 1000;
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
