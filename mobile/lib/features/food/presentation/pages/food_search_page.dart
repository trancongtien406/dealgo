import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/design_system/components/dealgo_chip.dart';
import '../../../../core/design_system/tokens/dealgo_tokens.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../identity/presentation/widgets/auth_widgets.dart';
import '../../domain/entities/food_models.dart';
import '../../domain/entities/food_money.dart';
import '../../domain/usecases/list_food_stores.dart';
import '../cubit/food_discovery_cubit.dart';
import '../utils/food_routes.dart';
import '../widgets/food_widgets.dart';

/// C023 — dedicated food search (suggestions, history, popular keywords).
class FoodSearchPage extends StatelessWidget {
  const FoodSearchPage({this.initialQuery = '', super.key});

  final String initialQuery;

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) =>
          FoodDiscoveryCubit(listFoodStores: context.read<ListFoodStores>())
            ..load(currentAccessToken(context)),
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

  static const _history = <String>[
    'Cơm tấm gần tôi',
    'Trà sữa Gong Cha',
    'Mì Quảng Đà Nẵng',
  ];

  static const _popular = <String>[
    'Bún bò',
    'Cơm gà',
    'Ăn sáng',
    'Trà sữa',
    'Pizza',
  ];

  @override
  void dispose() {
    _query.dispose();
    super.dispose();
  }

  void _openStore(FoodStoreSummary store) {
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
    final q = _query.text.trim().toLowerCase();
    final matches = [
      for (final store in stores)
        if (q.isEmpty || store.name.toLowerCase().contains(q)) store,
    ];

    return Scaffold(
      backgroundColor: DealGoColors.canvas,
      body: SafeArea(
        child: Column(
          children: [
            FoodScreenHeader(
              title: l10n.foodSearchTitle,
              trailing: const DealGoWordmark(),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: DealGoDimensions.pageGutter,
              ),
              child: TextField(
                key: const Key('food-search-field'),
                controller: _query,
                autofocus: true,
                textInputAction: TextInputAction.search,
                onChanged: (_) => setState(() {}),
                decoration: InputDecoration(
                  hintText: l10n.foodSearchHint,
                  prefixIcon: const Icon(
                    Icons.search,
                    color: DealGoColors.primary,
                  ),
                  suffixIcon: _query.text.isEmpty
                      ? null
                      : IconButton(
                          onPressed: () {
                            _query.clear();
                            setState(() {});
                          },
                          icon: const Icon(Icons.close),
                        ),
                  filled: true,
                  fillColor: DealGoColors.card,
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(DealGoRadius.input),
                    borderSide: const BorderSide(color: DealGoColors.primary),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(DealGoRadius.input),
                    borderSide: const BorderSide(
                      color: DealGoColors.primary,
                      width: 1.4,
                    ),
                  ),
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
                    ('stores', l10n.foodSearchFilterStores),
                    ('dishes', l10n.foodSearchFilterDishes),
                    ('near', l10n.foodSearchFilterNear),
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
                  for (final store in matches.take(4)) ...[
                    _ResultCard(store: store, onTap: () => _openStore(store)),
                    const SizedBox(height: DealGoSpacing.s12),
                  ],
                  if (matches.isEmpty)
                    Text(
                      l10n.foodSearchEmpty,
                      style: textTheme.bodyMedium?.copyWith(
                        color: DealGoColors.textSecondary,
                      ),
                    ),
                  const SizedBox(height: DealGoSpacing.s8),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          l10n.foodSearchHistory,
                          style: textTheme.titleMedium,
                        ),
                      ),
                      Text(
                        l10n.foodSearchClearHistory,
                        style: textTheme.labelSmall?.copyWith(
                          color: DealGoColors.primary,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: DealGoSpacing.s8),
                  for (final item in _history)
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: const Icon(
                        Icons.history,
                        color: DealGoColors.textSecondary,
                      ),
                      title: Text(item),
                      trailing: const Icon(
                        Icons.chevron_right,
                        color: DealGoColors.textSecondary,
                      ),
                      onTap: () {
                        _query.text = item;
                        setState(() {});
                      },
                    ),
                  const SizedBox(height: DealGoSpacing.s12),
                  Text(l10n.foodSearchPopular, style: textTheme.titleMedium),
                  const SizedBox(height: DealGoSpacing.s12),
                  Wrap(
                    spacing: DealGoSpacing.s8,
                    runSpacing: DealGoSpacing.s8,
                    children: [
                      for (final keyword in _popular)
                        DealGoChip(
                          label: '🔥 $keyword',
                          tone: DealGoChipTone.neutral,
                          onTap: () {
                            _query.text = keyword;
                            setState(() {});
                          },
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
  const _ResultCard({required this.store, required this.onTap});

  final FoodStoreSummary store;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final l10n = AppLocalizations.of(context);
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(DealGoRadius.card),
        child: FoodPanel(
          child: Row(
            children: [
              const FoodThumb(),
              const SizedBox(width: DealGoSpacing.s12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(store.name, style: textTheme.titleMedium),
                    Text(
                      '★ 4.8 · ${l10n.foodCategoryVietnamese} · 1,1 km',
                      style: textTheme.bodySmall,
                    ),
                    const SizedBox(height: DealGoSpacing.s8),
                    DealGoChip(
                      label: l10n.foodFreeshipChip,
                      tone: DealGoChipTone.success,
                    ),
                  ],
                ),
              ),
              Text(
                formatVnd(35000),
                style: textTheme.titleSmall?.copyWith(
                  color: DealGoColors.primary,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
