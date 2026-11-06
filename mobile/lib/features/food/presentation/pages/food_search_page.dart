import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/design_system/components/dealgo_skeleton.dart';
import '../../../../core/design_system/components/dealgo_state_view.dart';
import '../../../../core/design_system/components/dealgo_text_field.dart';
import '../../../../core/design_system/icons/dealgo_icons.dart';
import '../../../../core/design_system/tokens/dealgo_tokens.dart';
import '../../../../l10n/app_localizations.dart';
import '../../domain/entities/food_models.dart';
import '../../domain/params/get_food_store_params.dart';
import '../../domain/repositories/food_repository.dart';
import '../../domain/usecases/get_food_store.dart';
import '../cubit/food_search_cubit.dart';
import '../utils/food_routes.dart';
import '../widgets/food_cart_bar.dart';
import '../widgets/food_filter_sheet.dart';
import '../widgets/food_search_sections.dart';
import '../widgets/food_widgets.dart';
import '../../data/food_search_history.dart';
import '../../../../core/design_system/components/dealgo_app_header.dart';
import '../../../../core/design_system/components/dealgo_refresh.dart';
import 'food_item_options_page.dart';

const _initialSort = 'distance';

/// C023 — dedicated food search (dish hits, suggestions, history).
class FoodSearchPage extends StatelessWidget {
  const FoodSearchPage({this.initialQuery = '', super.key});

  final String initialQuery;

  @override
  Widget build(BuildContext context) {
    final origin = foodCartOrigin(context);
    return BlocProvider(
      create: (context) =>
          FoodSearchCubit(context.read<FoodRepository>())..load(
            currentAccessToken(context) ?? '',
            q: initialQuery,
            lat: origin.lat,
            lng: origin.lng,
            sortBy: _initialSort,
          ),
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
  static const _debounceDelay = Duration(milliseconds: 350);
  static const _maxKeywords = 6;

  final ScrollController _scroll = ScrollController();
  late final TextEditingController _query = TextEditingController(
    text: widget.initialQuery,
  );
  String _sortBy = _initialSort;
  var _history = const <String>[];
  var _keywords = const <String>[];
  Timer? _debounce;
  var _openingDish = false;

  /// Text the server was last asked for; while it matches the box the list
  /// is the server's answer for that keyword.
  late String _serverQuery = widget.initialQuery.trim().toLowerCase();

  Future<void> _load(String search) {
    final origin = foodCartOrigin(context);
    return context.read<FoodSearchCubit>().load(
      currentAccessToken(context) ?? '',
      q: search,
      lat: origin.lat,
      lng: origin.lng,
      sortBy: _sortBy,
    );
  }

  void _onQueryChanged() {
    setState(() {});
    _debounce?.cancel();
    _debounce = Timer(_debounceDelay, () {
      if (!mounted) return;
      final q = _query.text.trim();
      if (q.toLowerCase() == _serverQuery) return;
      _serverQuery = q.toLowerCase();
      _load(q);
    });
  }

  void _setSort(String sortBy) {
    if (_sortBy == sortBy) return;
    setState(() => _sortBy = sortBy);
    _load(_query.text.trim());
  }

  void _onScroll() {
    if (!_scroll.hasClients) return;
    final position = _scroll.position;
    if (position.maxScrollExtent <= 0) return;
    if (position.pixels < position.maxScrollExtent - 400) return;
    final q = _query.text.trim().toLowerCase();
    if (q.isEmpty || q != _serverQuery) return;
    final state = context.read<FoodSearchCubit>().state;
    final ready = switch (state) {
      FoodSearchReady ready => ready,
      FoodSearchLoading(:final previous) => previous,
      _ => null,
    };
    if (ready == null || ready.loadMoreFailed || !ready.hasMore) return;
    context.read<FoodSearchCubit>().loadMore();
  }

  @override
  void initState() {
    super.initState();
    _scroll.addListener(_onScroll);
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
    _scroll.removeListener(_onScroll);
    _scroll.dispose();
    _query.dispose();
    super.dispose();
  }

  void _openStore(FoodStoreSummary store) {
    _remember();
    context.push(FoodRoutes.store(store.id));
  }

  /// Resolves the real store before opening the item page: the hit carries no
  /// option groups, minimum order or availability, so a synthetic store would
  /// let customers configure a line the server later rejects.
  Future<void> _openDish(FoodDishHit hit) async {
    if (_openingDish) return;
    _openingDish = true;
    _remember();
    final messenger = ScaffoldMessenger.maybeOf(context);
    final l10n = AppLocalizations.of(context);
    final token = currentAccessToken(context);
    if (token == null || token.isEmpty) {
      _openingDish = false;
      messenger?.showSnackBar(SnackBar(content: Text(l10n.errorGeneric)));
      return;
    }
    try {
      final store = await context.read<GetFoodStore>()(
        GetFoodStoreParams(accessToken: token, storeId: hit.store.id),
      );
      if (!mounted) return;
      final item = store.items
          .where((candidate) => candidate.id == hit.item.id)
          .firstOrNull;
      if (item == null || !item.available) {
        messenger?.showSnackBar(
          SnackBar(content: Text(l10n.foodSearchDishUnavailable)),
        );
        return;
      }
      openFoodItemOptions(context: context, store: store, item: item);
    } catch (_) {
      messenger?.showSnackBar(SnackBar(content: Text(l10n.errorGeneric)));
    } finally {
      _openingDish = false;
    }
  }

  void _onKeywords(FoodSearchReady ready) {
    final names = <String>{};
    for (final store in ready.stores) {
      for (final dish in store.featuredItems) {
        final name = dish.name.trim();
        if (name.isNotEmpty) names.add(name);
        if (names.length >= _maxKeywords) break;
      }
      if (names.length >= _maxKeywords) break;
    }
    if (names.isEmpty) {
      if (_keywords.isNotEmpty) setState(() => _keywords = const []);
      return;
    }
    setState(() => _keywords = List.unmodifiable(names));
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final textTheme = Theme.of(context).textTheme;
    final state = context.watch<FoodSearchCubit>().state;
    final ready = switch (state) {
      FoodSearchReady ready => ready,
      FoodSearchLoading(:final previous) => previous,
      _ => null,
    };
    final failure = state is FoodSearchFailed ? state.message : null;
    final refreshing = state is FoodSearchLoading;
    final loading = failure == null && ready == null;
    final q = _query.text.trim();
    final searching = q.isNotEmpty;
    return Scaffold(
      // The body's SafeArea sits above the bar while the cart has items.
      extendBody: true,
      bottomNavigationBar: const FoodCartBar(),
      backgroundColor: DealGoColors.canvas,
      body: BlocListener<FoodSearchCubit, FoodSearchState>(
        listenWhen: (previous, current) => current is FoodSearchReady,
        listener: (context, state) {
          if (state is FoodSearchReady) _onKeywords(state);
        },
        child: SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
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
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: DealGoDimensions.pageGutter,
                ),
                child: Wrap(
                  spacing: DealGoSpacing.s8,
                  runSpacing: DealGoSpacing.s8,
                  children: [
                    for (final entry in [
                      (
                        'distance',
                        l10n.foodSearchFilterNear,
                        DealGoIcons.myLocation,
                      ),
                      (
                        'createdAt',
                        l10n.foodSearchSortNewest,
                        DealGoIcons.stars,
                      ),
                      (
                        'rating',
                        l10n.foodCategorySortRating,
                        DealGoIcons.starFilled,
                      ),
                    ])
                      FoodFilterPill(
                        key: Key('food-search-sort-${entry.$1}'),
                        label: entry.$2,
                        icon: entry.$3,
                        selected: _sortBy == entry.$1,
                        onTap: () => _setSort(entry.$1),
                      ),
                  ],
                ),
              ),
              Expanded(
                child: DealGoRefresh(
                  onRefresh: () => _load(_query.text.trim()),
                  child: ListView(
                    controller: _scroll,
                    padding: const EdgeInsets.fromLTRB(
                      DealGoDimensions.pageGutter,
                      DealGoSpacing.s12,
                      DealGoDimensions.pageGutter,
                      DealGoSpacing.s24,
                    ),
                    children: [
                      if (refreshing && ready != null)
                        const Padding(
                          padding: EdgeInsets.only(bottom: DealGoSpacing.s12),
                          child: LinearProgressIndicator(minHeight: 2),
                        ),
                      if (!searching) ...[
                        if (_keywords.isNotEmpty) ...[
                          Text(
                            l10n.foodSearchSuggestions,
                            key: const Key('food-search-heading'),
                            style: textTheme.titleMedium,
                          ),
                          const SizedBox(height: DealGoSpacing.s8),
                          Wrap(
                            spacing: DealGoSpacing.s8,
                            runSpacing: DealGoSpacing.s4,
                            children: [
                              for (final keyword in _keywords)
                                FoodFilterPill(
                                  key: Key('food-search-keyword-$keyword'),
                                  label: keyword,
                                  onTap: () {
                                    _query.text = keyword;
                                    _onQueryChanged();
                                  },
                                ),
                            ],
                          ),
                          const SizedBox(height: DealGoSpacing.s12),
                        ],
                        FoodSearchSuggestions(
                          history: _history,
                          onClearHistory: _clearHistory,
                          onHistoryTap: (item) {
                            _query.text = item;
                            _onQueryChanged();
                          },
                        ),
                      ] else if (failure != null)
                        DealGoStateView.failure(
                          context,
                          onRetry: () => _load(q),
                          cause: failure.error,
                          message: failure.resolve(l10n),
                          compact: true,
                        )
                      else if (loading)
                        const DealGoSkeletonList(itemCount: 3)
                      else if (ready != null)
                        FoodSearchResults(
                          ready: ready,
                          refreshing: refreshing,
                          onDishTap: _openDish,
                          onStoreTap: _openStore,
                          onLoadMore: () =>
                              context.read<FoodSearchCubit>().loadMore(),
                        ),
                      const SizedBox(height: DealGoSpacing.s8),
                      if (!searching) const FoodSearchCategories(),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
