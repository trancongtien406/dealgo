import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/design_system/components/dealgo_chip.dart';
import '../../../../core/design_system/components/dealgo_skeleton.dart';
import '../../../../core/design_system/components/dealgo_state_view.dart';
import '../../../../core/design_system/components/dealgo_text_field.dart';
import '../../../../core/design_system/tokens/dealgo_tokens.dart';
import '../../../../l10n/app_localizations.dart';
import '../../domain/entities/food_models.dart';
import '../../domain/usecases/list_food_stores.dart';
import '../../../../core/location/location_service.dart';
import '../../../rating/domain/service_rating.dart';
import '../cubit/food_discovery_cubit.dart';
import '../utils/food_routes.dart';
import '../widgets/food_widgets.dart';
import '../widgets/store_meta.dart';
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
      )..load(currentAccessToken(context)),
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
            store.name.toLowerCase().contains(q) ||
            (storeCategoryLabel(
                  l10n,
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
                onChanged: (_) => setState(() {}),
                onSubmitted: (_) => _remember(),
                suffix: _query.text.isEmpty
                    ? null
                    : IconButton(
                        onPressed: () {
                          _query.clear();
                          setState(() {});
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
                  Text(
                    l10n.foodSearchSuggestionsHint,
                    style: textTheme.bodySmall,
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
                      leading: const Icon(
                        DealGoIcons.history,
                        color: DealGoColors.textSecondary,
                      ),
                      title: Text(item),
                      trailing: const Icon(
                        DealGoIcons.chevronRight,
                        color: DealGoColors.textSecondary,
                      ),
                      onTap: () {
                        _query.text = item;
                        setState(() {});
                      },
                    ),
                  const SizedBox(height: DealGoSpacing.s12),
                  Text(l10n.foodSearchGroups, style: textTheme.titleMedium),
                  const SizedBox(height: DealGoSpacing.s12),
                  Wrap(
                    spacing: DealGoSpacing.s8,
                    runSpacing: DealGoSpacing.s8,
                    children: [
                      for (final group in FoodStoreGroup.values.skip(1))
                        DealGoChip(
                          label: group.label(l10n),
                          tone: DealGoChipTone.neutral,
                          leading: Icon(
                            group.icon,
                            size: 14,
                            color: group.color,
                          ),
                          onTap: () => context.push(
                            '${FoodRoutes.category}?group=${group.wire}',
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
    final textTheme = Theme.of(context).textTheme;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(DealGoRadius.card),
        child: FoodPanel(
          child: Row(
            children: [
              FoodThumb(imageUrl: store.imageUrl),
              const SizedBox(width: DealGoSpacing.s12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(store.name, style: textTheme.titleMedium),
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
