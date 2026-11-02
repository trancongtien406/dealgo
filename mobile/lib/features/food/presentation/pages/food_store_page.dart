import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:geolocator/geolocator.dart';

import '../../../../core/config/api_base_url.dart';
import '../../../../core/location/location_service.dart';
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
import '../widgets/food_category_tile.dart';
import '../food_categories_store.dart';
import '../widgets/food_cart_bar.dart';
import '../widgets/store_meta.dart';
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

/// Height of the pinned tab bar; the section chips add [_chipsHeight].
const double _tabsHeight = 46;
const double _chipsHeight = 48;

class _FoodStorePageState extends State<_FoodStoreView> {
  final ScrollController _scroll = ScrollController();
  final TextEditingController _query = TextEditingController();
  final Map<String, GlobalKey> _sectionKeys = {};
  FoodStoreDetail? _store;
  StoreReviews? _reviews;
  StoreReviews? _filtered;
  int? _reviewStars;
  var _reviewsBusy = false;
  var _loading = true;
  Object? _failure;
  var _tab = _StoreTab.menu;
  double? _distanceKm;
  String? _activeSection;

  @override
  void initState() {
    super.initState();
    _query.addListener(() => setState(() {}));
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  @override
  void dispose() {
    _scroll.dispose();
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

  /// Straight-line distance, only when location is already allowed.
  Future<void> _locate(FoodStoreDetail store) async {
    final lat = store.lat;
    final lng = store.lng;
    if (lat == null || lng == null) return;
    LocationService? location;
    try {
      location = context.read<LocationService>();
    } on Object {
      return;
    }
    try {
      final position = await location.quietPosition().timeout(
        const Duration(seconds: 5),
      );
      if (position == null || !mounted) return;
      final km =
          Geolocator.distanceBetween(
            position.latitude,
            position.longitude,
            lat,
            lng,
          ) /
          1000;
      setState(() => _distanceKm = km);
      context.read<FoodCartCubit>().setStoreDistance(widget.storeId, km);
    } on Object {
      return;
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

  void _jumpTo(String id, double pinned) {
    setState(() => _activeSection = id);
    final target = _sectionKeys[id]?.currentContext?.findRenderObject();
    if (target == null || !_scroll.hasClients) return;
    final viewport = RenderAbstractViewport.of(target);
    final offset = viewport.getOffsetToReveal(target, 0).offset - pinned;
    final max = _scroll.position.maxScrollExtent;
    final to = offset.clamp(0.0, max);
    if (MediaQuery.disableAnimationsOf(context)) {
      _scroll.jumpTo(to);
    } else {
      _scroll.animateTo(
        to,
        duration: const Duration(milliseconds: 320),
        curve: Curves.easeOutCubic,
      );
    }
  }

  void _openReviews() {
    setState(() => _tab = _StoreTab.reviews);
  }

  @override
  Widget build(BuildContext context) {
    final store = _store;
    final l10n = AppLocalizations.of(context);
    const gutter = EdgeInsets.symmetric(
      horizontal: DealGoDimensions.pageGutter,
    );
    Widget body() {
      final current = store!;
      final groups = _groups(current, l10n);
      final named = [
        for (final group in groups)
          if (group.title != null) group,
      ];
      final showChips =
          _tab == _StoreTab.menu &&
          _query.text.trim().isEmpty &&
          named.length > 1;
      final pinned = _tabsHeight + (showChips ? _chipsHeight : 0);
      for (final group in groups) {
        _sectionKeys.putIfAbsent(group.id, GlobalKey.new);
      }
      final rating = _reviews?.summary;
      return CustomScrollView(
        controller: _scroll,
        slivers: [
          SliverPadding(
            padding: gutter,
            sliver: SliverList.list(
              children: [
                _Hero(store: current),
                const SizedBox(height: DealGoSpacing.s16),
                _StoreHeading(
                  store: current,
                  rating: rating,
                  reviews: _reviews,
                  distanceKm: _distanceKm,
                  onRatingTap: _openReviews,
                ),
                if (current.offers.isNotEmpty) ...[
                  const SizedBox(height: DealGoSpacing.s16),
                  _StoreOffers(offers: current.offers, storeId: current.id),
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
                  if (showChips)
                    SizedBox(
                      height: _chipsHeight,
                      child: ListView.separated(
                        key: const Key('food-menu-sections'),
                        scrollDirection: Axis.horizontal,
                        padding: const EdgeInsets.fromLTRB(
                          DealGoDimensions.pageGutter,
                          DealGoSpacing.s8,
                          DealGoDimensions.pageGutter,
                          DealGoSpacing.s8,
                        ),
                        itemCount: named.length,
                        separatorBuilder: (context, index) =>
                            const SizedBox(width: DealGoSpacing.s8),
                        itemBuilder: (context, index) {
                          final group = named[index];
                          final active =
                              (_activeSection ?? named.first.id) == group.id;
                          return ChoiceChip(
                            key: Key('food-menu-section-${group.id}'),
                            label: Text(group.title!),
                            selected: active,
                            showCheckmark: false,
                            onSelected: (_) => _jumpTo(group.id, pinned),
                            selectedColor: DealGoColors.subtlePurple,
                            labelStyle: TextStyle(
                              color: active
                                  ? DealGoColors.primary
                                  : DealGoColors.textSecondary,
                              fontWeight: active
                                  ? FontWeight.w700
                                  : FontWeight.w500,
                            ),
                            side: BorderSide(
                              color: active
                                  ? DealGoColors.primary
                                  : DealGoColors.border,
                            ),
                            visualDensity: VisualDensity.compact,
                          );
                        },
                      ),
                    ),
                ],
              ),
            ),
          ),
          SliverPadding(
            // Room for the floating cart bar, above the home indicator.
            padding: dealGoScrollPadding(
              context,
              const EdgeInsets.fromLTRB(
                DealGoDimensions.pageGutter,
                DealGoSpacing.s12,
                DealGoDimensions.pageGutter,
                DealGoSpacing.s24 + kFoodCartBarRoom,
              ),
            ),
            sliver: SliverList.list(
              children: [
                DealGoStatusSwitcher(
                  child: switch (_tab) {
                    _StoreTab.menu => _Menu(
                      key: const ValueKey('menu'),
                      store: current,
                      groups: groups,
                      sectionKeys: _sectionKeys,
                      query: _query,
                    ),
                    _StoreTab.reviews => _Reviews(
                      key: const ValueKey('reviews'),
                      reviews: _reviews,
                      filtered: _reviewStars == null ? _reviews : _filtered,
                      stars: _reviewStars,
                      busy: _reviewsBusy,
                      onFilter: _filterReviews,
                      onMore: _moreReviews,
                    ),
                    _StoreTab.info => _StoreInfo(
                      key: const ValueKey('info'),
                      store: current,
                    ),
                  },
                ),
              ],
            ),
          ),
        ],
      );
    }

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
                  : body(),
            ),
          ],
        ),
      ),
      bottomNavigationBar: store == null
          ? null
          : FoodCartBar(storeId: store.id, offers: store.offers),
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
    this.rating,
    this.reviews,
    this.distanceKm,
  });

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
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: EdgeInsets.only(top: 1),
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
            ],
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
              FoodInfoChip(
                key: const Key('food-store-distance'),
                label: formatDistanceKm(context, distance),
                icon: DealGoIcons.pin,
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

class _Menu extends StatelessWidget {
  const _Menu({
    required this.store,
    required this.groups,
    required this.sectionKeys,
    required this.query,
    super.key,
  });

  final FoodStoreDetail store;
  final List<_MenuGroup> groups;
  final Map<String, GlobalKey> sectionKeys;
  final TextEditingController query;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    if (store.items.isEmpty) {
      return FoodPanel(child: Text(l10n.foodStoreNoItems));
    }
    final textTheme = Theme.of(context).textTheme;
    final best = foodBestSellerIds(store.items);
    var index = 0;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextField(
          key: const Key('food-store-search'),
          controller: query,
          textInputAction: TextInputAction.search,
          decoration: InputDecoration(
            hintText: l10n.foodStoreSearchMenu,
            prefixIcon: const Icon(
              DealGoIcons.search,
              color: DealGoColors.primary,
            ),
            suffixIcon: query.text.isEmpty
                ? null
                : IconButton(
                    key: const Key('food-store-search-clear'),
                    tooltip: MaterialLocalizations.of(context)
                        .deleteButtonTooltip,
                    onPressed: query.clear,
                    icon: const Icon(DealGoIcons.close, size: 18),
                  ),
            filled: true,
            fillColor: DealGoColors.card,
            isDense: true,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(DealGoRadius.button),
              borderSide: BorderSide(color: DealGoColors.border),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(DealGoRadius.button),
              borderSide: BorderSide(color: DealGoColors.border),
            ),
          ),
        ),
        const SizedBox(height: DealGoSpacing.s12),
        if (groups.isEmpty)
          FoodPanel(
            key: const Key('food-store-search-empty'),
            child: Text(l10n.foodStoreSearchNone),
          ),
        for (final group in groups) ...[
          if (group.title != null || query.text.isEmpty)
            Padding(
              key: sectionKeys[group.id],
              padding: const EdgeInsets.only(
                top: DealGoSpacing.s8,
                bottom: DealGoSpacing.s8,
              ),
              child: Text(
                group.title == null
                    ? l10n.foodStoreMenuCount(group.items.length)
                    : '${group.title} (${group.items.length})',
                style: textTheme.titleMedium,
              ),
            )
          else
            SizedBox(key: sectionKeys[group.id], height: 0),
          for (final item in group.items) ...[
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
            const SizedBox(height: DealGoSpacing.s12),
          ],
        ],
      ],
    );
  }
}

class _MenuItem extends StatelessWidget {
  const _MenuItem({
    required this.store,
    required this.item,
    this.featured = false,
    this.bestSeller = false,
    super.key,
  });

  final FoodStoreDetail store;
  final FoodMenuItem item;
  final bool bestSeller;

  /// Copy in the best-sellers group: its own add key and no hero flight.
  final bool featured;

  Widget _thumb() => FoodThumb(
    size: 84,
    imageUrl: item.imageUrl,
    placeholderAsset: foodDishFallbackImage(store.category),
  );

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
              // Only items that open the options page fly their photo there.
              item.optionGroups.isEmpty || featured
                  ? _thumb()
                  : DealGoHero(tag: foodItemHeroTag(item.id), child: _thumb()),
              const SizedBox(width: DealGoSpacing.s12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.name,
                      style: textTheme.titleMedium?.copyWith(fontSize: 16),
                    ),
                    if (item.isNew || bestSeller) ...[
                      const SizedBox(height: DealGoSpacing.s4),
                      FoodItemBadges(isNew: item.isNew, bestSeller: bestSeller),
                    ],
                    if (description != null && description.isNotEmpty) ...[
                      const SizedBox(height: DealGoSpacing.s4),
                      Text(description, style: textTheme.bodySmall),
                    ],
                    if (item.soldCount > 0) ...[
                      const SizedBox(height: DealGoSpacing.s4),
                      Text(
                        l10n.foodItemSold(item.soldCount),
                        style: textTheme.labelSmall?.copyWith(
                          color: DealGoColors.textSecondary,
                        ),
                      ),
                    ],
                    if (item.prepMinutes != null) ...[
                      const SizedBox(height: DealGoSpacing.s4),
                      Row(
                        children: [
                          Icon(
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
                          child: FoodPriceText(
                            key: Key('food-price-${item.id}'),
                            priceVnd: item.priceVnd,
                            originalPriceVnd: item.originalPriceVnd,
                            size: 16,
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
                          _QuantityControl(
                            store: store,
                            item: item,
                            keyPrefix: featured ? 'food-best-add' : 'food-add',
                          ),
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
  const _QuantityControl({
    required this.store,
    required this.item,
    this.keyPrefix = 'food-add',
  });

  final FoodStoreDetail store;
  final FoodMenuItem item;
  final String keyPrefix;

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
        key: Key('$keyPrefix-${item.id}'),
        tooltip: AppLocalizations.of(context).foodAddToCart,
        onPressed: () {
          if (hasOptions) {
            openFoodItemOptions(context: context, store: store, item: item);
            return;
          }
          cart.addItem(
            storeId: store.id,
            storeName: store.name,
            item: item,
            minOrderVnd: store.minOrderVnd,
            prepMinutes: store.estimatedPrepMinutes,
          );
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
          key: Key('$keyPrefix-${item.id}'),
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
                    minOrderVnd: store.minOrderVnd,
                    prepMinutes: store.estimatedPrepMinutes,
                  );
                },
          icon: const Icon(DealGoIcons.add),
        ),
      ],
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
    super.key,
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
  const _StoreInfo({required this.store, super.key});

  final FoodStoreDetail store;

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
    return FoodPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          row(DealGoIcons.store, l10n.foodStoreInfoName, store.name),
          if (store.description != null)
            row(DealGoIcons.info, l10n.foodStoreAbout, store.description!),
          if (category != null)
            row(DealGoIcons.restaurant, l10n.foodStoreInfoCategory, category),
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
