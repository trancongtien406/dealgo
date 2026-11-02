import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/design_system/components/dealgo_chip.dart';
import '../../../../core/design_system/components/dealgo_skeleton.dart';
import '../../../../core/design_system/components/dealgo_state_view.dart';
import '../../../../core/design_system/components/dealgo_text_field.dart';
import '../../../../core/design_system/tokens/dealgo_tokens.dart';
import '../../../../l10n/app_localizations.dart';
import '../../domain/entities/food_category.dart';
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
import '../widgets/food_category_tile.dart';
import '../../data/food_search_history.dart';
import '../../../../core/design_system/icons/dealgo_icons.dart';
import '../../../../core/design_system/components/dealgo_app_header.dart';

/// C023 — dedicated food search (suggestions, history, popular keywords).
class FoodSearchPage extends StatelessWidget {
  const FoodSearchPage({this.initialQuery = '', super.key});

  final String initialQuery;

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) => FoodDiscoveryCubit(
        listFoodStores: context.read<ListFoodStores>(),
        ratings: context.read<RatingRepository>(),
        location: context.read<LocationService>(),
      )..load(currentAccessToken(context), search: initialQuery.trim()),
      child: _FoodSearchView(initialQuery: initialQuery),
    );
  }
}

class _FoodSearchView extends StatefulWidget {
  const _FoodSearchView({required this.initialQuery});

  final String initialQuery;

  @override
  State<_FoodSearchView> createState() => _FoodSearchViewState();
}

class _FoodSearchViewState extends State<_FoodSearchView> {
  late final TextEditingController _query = TextEditingController(
    text: widget.initialQuery,
  );
  var _filter = 'all';
  var _history = const <String>[];
  Timer? _debounce;

  /// Text the server was last asked for; while it matches the box the list
  /// is the server's answer (name, dish, category), not a local filter.
  late String _serverQuery = widget.initialQuery.trim().toLowerCase();

  /// QA C3 — search the whole catalog on the server (debounced).
  void _onQueryChanged() {
    setState(() {});
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 350), () {
      if (!mounted) return;
      final q = _query.text.trim();
      if (q.toLowerCase() == _serverQuery) return;
      _serverQuery = q.toLowerCase();
      unawaited(
        context.read<FoodDiscoveryCubit>().load(
          currentAccessToken(context),
          search: q,
        ),
      );
    });
  }

  @override
  void initState() {
    super.initState();
    FoodSearchHistory.load().then((items) {
      if (mounted) setState(() => _history = items);
    });
  }

  Future<void> _remember() async {
    final items = await FoodSearchHistory.add(_query.text);
    if (mounted) setState(() => _history = items);
  }

  Future<void> _clearHistory() async {
    await FoodSearchHistory.clear();
    if (mounted) setState(() => _history = const []);
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _query.dispose();
    super.dispose();
  }

  void _openStore(FoodStoreSummary store) {
    _remember();
    context.push(FoodRoutes.store(store.id));
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final textTheme = Theme.of(context).textTheme;
    final discovery = context.watch<FoodDiscoveryCubit>().state;
    final stores = switch (discovery) {
      FoodDiscoveryReady(:final stores) => stores,
      _ => const <FoodStoreSummary>[],
    };
    final ratings = switch (discovery) {
      FoodDiscoveryReady(:final ratings) => ratings,
      _ => const <String, StoreRating>{},
    };
    final q = _query.text.trim().toLowerCase();
    final matches = [
      for (final store in stores)
        if (q.isEmpty ||
            q == _serverQuery ||
            store.name.toLowerCase().contains(q) ||
            (foodCategoryLabel(
                  context,
                  store.category,
                )?.toLowerCase().contains(q) ??
                false))
          store,
    ];
    if (_filter == 'near') {
      matches.sort(
        (a, b) => (a.distanceKm ?? double.infinity).compareTo(
          b.distanceKm ?? double.infinity,
        ),
      );
    } else if (_filter == 'rating') {
      matches.sort(
        (a, b) => (ratings[b.id]?.average ?? -1).compareTo(
          ratings[a.id]?.average ?? -1,
        ),
      );
    }

    return Scaffold(
      // The body's SafeArea sits above the bar while the cart has items.
      extendBody: true,
      bottomNavigationBar: const FoodCartBar(),
      backgroundColor: DealGoColors.canvas,
      body: SafeArea(
        child: Column(
          children: [
            DealGoAppHeader(title: l10n.foodSearchTitle),
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: DealGoDimensions.pageGutter,
              ),
              child: DealGoTextField(
                label: l10n.foodSearchHint,
                showLabel: false,
                hint: l10n.foodSearchHint,
                prefixIcon: DealGoIcons.search,
                controller: _query,
                fieldKey: const Key('food-search-field'),
                autofocus: true,
                textInputAction: TextInputAction.search,
                onChanged: (_) => _onQueryChanged(),
                onSubmitted: (_) => _remember(),
                suffix: _query.text.isEmpty
                    ? null
                    : IconButton(
                        onPressed: () {
                          _query.clear();
                          _onQueryChanged();
                        },
                        icon: const Icon(DealGoIcons.close),
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
                    ('all', l10n.foodSearchFilterAll),
                    ('near', l10n.foodSearchFilterNear),
                    ('rating', l10n.foodCategorySortRating),
                  ]) ...[
                    DealGoChip(
                      label: entry.$2,
                      selected: _filter == entry.$1,
                      tone: DealGoChipTone.brand,
                      onTap: () => setState(() => _filter = entry.$1),
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
                  Text(
                    l10n.foodSearchSuggestions,
                    style: textTheme.titleMedium,
                  ),
                  const SizedBox(height: DealGoSpacing.s12),
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
                  else if (discovery is FoodDiscoveryLoading)
                    const DealGoSkeletonList(itemCount: 3)
                  else ...[
                    for (final store in matches.take(4)) ...[
                      _ResultCard(
                        store: store,
                        rating: ratings[store.id],
                        onTap: () => _openStore(store),
                      ),
                      const SizedBox(height: DealGoSpacing.s12),
                    ],
                    if (matches.isEmpty)
                      DealGoStateView(
                        art: DealGoStateArt.noSearch,
                        title: l10n.foodSearchEmpty,
                        compact: true,
                      ),
                  ],
                  const SizedBox(height: DealGoSpacing.s8),
                  if (_history.isNotEmpty) ...[
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            l10n.foodSearchHistory,
                            style: textTheme.titleMedium,
                          ),
                        ),
                        TextButton(
                          key: const Key('food-search-clear-history'),
                          onPressed: _clearHistory,
                          child: Text(
                            l10n.foodSearchClearHistory,
                            style: textTheme.labelSmall?.copyWith(
                              color: DealGoColors.primary,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: DealGoSpacing.s8),
                  ],
                  for (final item in _history)
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: Icon(
                        DealGoIcons.history,
                        color: DealGoColors.textSecondary,
                      ),
                      title: Text(item),
                      trailing: Icon(
                        DealGoIcons.chevronRight,
                        color: DealGoColors.textSecondary,
                      ),
                      onTap: () {
                        _query.text = item;
                        _onQueryChanged();
                      },
                    ),
                  const SizedBox(height: DealGoSpacing.s12),
                  Text(l10n.foodSearchGroups, style: textTheme.titleMedium),
                  const SizedBox(height: DealGoSpacing.s12),
                  Wrap(
                    spacing: DealGoSpacing.s8,
                    runSpacing: DealGoSpacing.s8,
                    children: [
                      for (final category
                          in maybeFoodCategories(context)?.items ??
                              const <FoodCategory>[])
                        DealGoChip(
                          key: Key('food-search-category-${category.code}'),
                          label: category.name(
                            Localizations.localeOf(context).languageCode,
                          ),
                          tone: DealGoChipTone.neutral,
                          leading: FoodCategoryAvatar(
                            category: category,
                            size: 20,
                          ),
                          onTap: () => context.push(
                            FoodRoutes.categoryOf(category.code),
                          ),
                        ),
                    ],
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

class _ResultCard extends StatelessWidget {
  const _ResultCard({required this.store, required this.onTap, this.rating});

  final FoodStoreSummary store;
  final StoreRating? rating;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return FoodStoreListCard(store: store, rating: rating, onTap: onTap);
  }
}
