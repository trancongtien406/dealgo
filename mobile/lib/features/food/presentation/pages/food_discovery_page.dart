import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/config/api_base_url.dart';
import '../../../../core/design_system/components/dealgo_state_view.dart';
import '../../../../core/design_system/tokens/dealgo_tokens.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../identity/presentation/widgets/auth_widgets.dart';
import '../../../places/presentation/place_picker_page.dart';
import '../../../ride/presentation/cubit/ride_destination.dart';
import '../../domain/entities/food_models.dart';
import '../../domain/usecases/list_food_stores.dart';
import '../../../../core/location/location_service.dart';
import '../../../rating/domain/service_rating.dart';
import '../cubit/food_discovery_cubit.dart';
import '../utils/food_routes.dart';
import '../widgets/food_widgets.dart';
import '../widgets/store_meta.dart';
import '../../../../core/design_system/icons/dealgo_icons.dart';
import '../../../../core/l10n/ui_message.dart';
import '../../../shell/presentation/customer_tab_bar.dart';
import '../../../../core/design_system/components/dealgo_skeleton.dart';

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
  var _group = FoodStoreGroup.near;

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
    final ratings = switch (discovery) {
      FoodDiscoveryReady(:final ratings) => ratings,
      _ => const <String, StoreRating>{},
    };
    final l10n = AppLocalizations.of(context);
    final byDistance = stores.any((store) => store.distanceKm != null);
    final loading = discovery is FoodDiscoveryLoading;
    final error = discovery is FoodDiscoveryFailed ? discovery.message : null;
    // One row on this page. The rest open from "Xem tất cả".
    final visible = stores.take(2).toList(growable: false);
    final popular = _popularThisWeek(stores, ratings);
    return SafeArea(
      bottom: dealGoSafeAreaBottom(context),
      child: ListView(
        controller: _scroll,
        padding: EdgeInsets.fromLTRB(
          DealGoDimensions.pageGutter,
          DealGoSpacing.s8,
          DealGoDimensions.pageGutter,
          customerShellBottomClearance(context),
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
          _FoodBanner(onExplore: _scrollToStores),
          const SizedBox(height: DealGoSpacing.s16),
          _CategoryStrip(
            selected: _group,
            onSelected: (group) {
              setState(() => _group = group);
              context.push('${FoodRoutes.category}?group=${group.wire}');
            },
          ),
          const SizedBox(height: DealGoSpacing.s20),
          _SectionHeader(
            title: l10n.foodDiscoveryStoresTitle,
            subtitle: byDistance
                ? l10n.foodDiscoverySortedByDistance
                : l10n.foodDiscoveryLocationOff,
            onSeeAll: () => context.push(
              '${FoodRoutes.category}?group=${FoodStoreGroup.near.wire}',
            ),
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
          if (popular.isNotEmpty) ...[
            const SizedBox(height: DealGoSpacing.s20),
            _SectionHeader(
              title: l10n.foodDiscoveryTopRatedTitle,
              subtitle: l10n.foodDiscoveryTopRatedSubtitle,
              onSeeAll: () => context.push(
                '${FoodRoutes.category}?group=${FoodStoreGroup.near.wire}',
              ),
            ),
            const SizedBox(height: DealGoSpacing.s12),
            for (final store in popular) ...[
              _WideStoreCard(
                store: store,
                rating: ratings[store.id],
                onTap: () => _openStore(store),
              ),
              const SizedBox(height: DealGoSpacing.s12),
            ],
          ],
        ],
      ),
    );
  }
}

/// Rated stores first. Otherwise the shops after the nearby row, so the
/// section stays on screen when a shop has no score yet.
List<FoodStoreSummary> _popularThisWeek(
  List<FoodStoreSummary> stores,
  Map<String, StoreRating> ratings,
) {
  if (stores.isEmpty) return const [];
  final rated = [
    for (final store in stores)
      if (ratings[store.id]?.average != null) store,
  ]..sort(
    (a, b) => ratings[b.id]!.average!.compareTo(ratings[a.id]!.average!),
  );
  final shown = stores.take(2).map((store) => store.id).toSet();
  final ranked = rated.isNotEmpty ? rated : stores.skip(2);
  final fresh = [
    for (final store in ranked)
      if (!shown.contains(store.id)) store,
  ];
  final picks = fresh.isNotEmpty
      ? fresh
      : (rated.isNotEmpty ? rated : stores);
  return picks.take(3).toList(growable: false);
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
      shape: const StadiumBorder(
        side: BorderSide(color: DealGoColors.border),
      ),
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
    final textTheme = Theme.of(context).textTheme;
    final l10n = AppLocalizations.of(context);
    return ClipRRect(
      borderRadius: BorderRadius.circular(DealGoRadius.button),
      child: SizedBox(
        height: 168,
        child: Stack(
          fit: StackFit.expand,
          children: [
            const ColoredBox(color: DealGoColors.primaryDeep),
            Image.asset(
              'assets/images/hero_food_clean.png',
              fit: BoxFit.cover,
              alignment: Alignment.centerRight,
              errorBuilder: (context, error, stackTrace) =>
                  const SizedBox.shrink(),
            ),
            const DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [Color(0xE6120B2E), Color(0x00120B2E)],
                  stops: [0.05, 0.72],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(DealGoSpacing.s16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    l10n.foodBannerKicker,
                    style: textTheme.labelSmall?.copyWith(
                      color: Colors.white.withValues(alpha: 0.86),
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.6,
                    ),
                  ),
                  const SizedBox(height: DealGoSpacing.s4),
                  Text(
                    l10n.foodBannerTitle,
                    style: textTheme.titleMedium?.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.w800,
                      height: 1.2,
                    ),
                  ),
                  const Spacer(),
                  FilledButton(
                    onPressed: onExplore,
                    style: FilledButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: DealGoColors.primary,
                      elevation: 0,
                      minimumSize: const Size(0, 36),
                      padding: const EdgeInsets.symmetric(
                        horizontal: DealGoSpacing.s16,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(
                          DealGoRadius.button,
                        ),
                      ),
                    ),
                    child: Text(l10n.foodBannerCta),
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

class _CategoryStrip extends StatelessWidget {
  const _CategoryStrip({required this.selected, required this.onSelected});

  final FoodStoreGroup selected;
  final ValueChanged<FoodStoreGroup> onSelected;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    const groups = FoodStoreGroup.values;
    return SizedBox(
      height: 100,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: groups.length,
        separatorBuilder: (context, index) =>
            const SizedBox(width: DealGoSpacing.s8),
        itemBuilder: (context, index) {
          final group = groups[index];
          final active = group == selected;
          return InkWell(
            key: Key('food-group-${group.wire}'),
            onTap: () => onSelected(group),
            borderRadius: BorderRadius.circular(12),
            child: SizedBox(
              width: 64,
              child: Column(
                children: [
                  DecoratedBox(
                    decoration: BoxDecoration(
                      color: group.background,
                      shape: BoxShape.circle,
                      border: active
                          ? Border.all(color: group.color, width: 1.5)
                          : null,
                    ),
                    child: SizedBox(
                      width: 56,
                      height: 56,
                      child: Icon(group.icon, color: group.color, size: 22),
                    ),
                  ),
                  const SizedBox(height: DealGoSpacing.s8),
                  Text(
                    group.label(l10n),
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: DealGoColors.text,
                      fontWeight: active ? FontWeight.w700 : FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({
    required this.title,
    required this.subtitle,
    required this.onSeeAll,
  });

  final String title;
  final String subtitle;
  final VoidCallback onSeeAll;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: textTheme.titleMedium),
              Text(subtitle, style: textTheme.bodySmall),
            ],
          ),
        ),
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
    return LayoutBuilder(
      builder: (context, constraints) {
        const gap = DealGoSpacing.s12;
        final tileWidth = (constraints.maxWidth - gap) / 2;
        return Wrap(
          spacing: gap,
          runSpacing: gap,
          children: [
            for (final store in stores)
              SizedBox(
                width: tileWidth,
                child: _StoreTile(
                  key: Key('food-store-card-${store.id}'),
                  store: store,
                  rating: ratings[store.id],
                  onTap: () => onOpen(store),
                ),
              ),
          ],
        );
      },
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
    return DecoratedBox(
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
          onTap: onTap,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                height: 128,
                width: double.infinity,
                child: _StoreCover(imageUrl: store.imageUrl),
              ),
              Padding(
                padding: const EdgeInsets.all(DealGoSpacing.s12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      store.name,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.titleMedium
                          ?.copyWith(fontSize: 15),
                    ),
                    const SizedBox(height: DealGoSpacing.s4),
                    StoreMetaLine(store: store, rating: rating),
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

class _WideStoreCard extends StatelessWidget {
  const _WideStoreCard({required this.store, required this.onTap, this.rating});

  final FoodStoreSummary store;
  final StoreRating? rating;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return DecoratedBox(
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
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(DealGoSpacing.s12),
            child: Row(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(DealGoRadius.input),
                  child: FoodThumb(size: 72, imageUrl: store.imageUrl),
                ),
                const SizedBox(width: DealGoSpacing.s12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        store.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: textTheme.titleMedium?.copyWith(fontSize: 16),
                      ),
                      const SizedBox(height: DealGoSpacing.s4),
                      StoreMetaLine(store: store, rating: rating),
                    ],
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

class _StoreCover extends StatelessWidget {
  const _StoreCover({this.imageUrl});

  final String? imageUrl;

  @override
  Widget build(BuildContext context) {
    final resolved = resolveMediaUrl(imageUrl);
    const placeholder = ColoredBox(
      color: DealGoColors.amberSurface,
      child: Icon(DealGoIcons.food, color: DealGoColors.amber, size: 40),
    );
    if (resolved == null || resolved.isEmpty) {
      return placeholder;
    }
    return Image.network(
      resolved,
      fit: BoxFit.cover,
      width: double.infinity,
      height: double.infinity,
      errorBuilder: (context, error, stack) => placeholder,
    );
  }
}
