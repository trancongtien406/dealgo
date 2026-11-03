import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/design_system/components/dealgo_chip.dart';
import '../../../../core/design_system/components/dealgo_state_view.dart';
import '../../../../core/design_system/icons/dealgo_icons.dart';
import '../../../../core/design_system/tokens/dealgo_tokens.dart';
import '../../../../l10n/app_localizations.dart';
import '../../domain/entities/food_category.dart';
import '../../domain/entities/food_models.dart';
import '../cubit/food_search_cubit.dart';
import '../food_categories_store.dart';
import '../utils/food_routes.dart';
import 'food_dish_hit_row.dart';
import 'food_feed_footer.dart';
import 'food_store_card.dart';
import 'food_category_tile.dart';

class FoodSearchResults extends StatelessWidget {
  const FoodSearchResults({
    required this.ready,
    required this.refreshing,
    required this.onDishTap,
    required this.onStoreTap,
    required this.onLoadMore,
    super.key,
  });

  final FoodSearchReady ready;
  final bool refreshing;
  final ValueChanged<FoodDishHit> onDishTap;
  final ValueChanged<FoodStoreSummary> onStoreTap;
  final VoidCallback onLoadMore;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final textTheme = Theme.of(context).textTheme;
    final empty = ready.dishes.isEmpty && ready.stores.isEmpty;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (ready.dishes.isNotEmpty) ...[
          Column(
            key: const Key('food-dish-hits'),
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(l10n.foodSearchDishes, style: textTheme.titleMedium),
              const SizedBox(height: DealGoSpacing.s8),
              for (final hit in ready.dishes) ...[
                FoodDishHitRow(
                  key: Key('food-dish-hit-${hit.item.id}'),
                  hit: hit,
                  onTap: () => onDishTap(hit),
                ),
                const SizedBox(height: DealGoSpacing.s8),
              ],
            ],
          ),
          const SizedBox(height: DealGoSpacing.s12),
        ],
        if (ready.stores.isNotEmpty) ...[
          Text(l10n.foodSearchStores, style: textTheme.titleMedium),
          const SizedBox(height: DealGoSpacing.s8),
          for (final store in ready.stores) ...[
            FoodStoreCard(
              key: Key('food-store-card-${store.id}'),
              store: store,
              onTap: () => onStoreTap(store),
            ),
            const SizedBox(height: DealGoSpacing.s12),
          ],
        ],
        if (empty)
          DealGoStateView(
            art: DealGoStateArt.noSearch,
            title: l10n.foodSearchEmpty,
            compact: true,
          )
        else
          FoodFeedFooter.paged(
            hasRows: true,
            isLoadingMore: ready.loadingMore,
            loadMoreFailed: ready.loadMoreFailed,
            hasMore: ready.hasMore,
            isRefreshing: refreshing,
            onRetry: onLoadMore,
          ),
      ],
    );
  }
}

class FoodSearchSuggestions extends StatelessWidget {
  const FoodSearchSuggestions({
    required this.history,
    required this.onClearHistory,
    required this.onHistoryTap,
    super.key,
  });

  final List<String> history;
  final VoidCallback onClearHistory;
  final ValueChanged<String> onHistoryTap;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final textTheme = Theme.of(context).textTheme;
    if (history.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(l10n.foodSearchHistory, style: textTheme.titleMedium),
            ),
            TextButton(
              key: const Key('food-search-clear-history'),
              onPressed: onClearHistory,
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
        for (final item in history)
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
            onTap: () => onHistoryTap(item),
          ),
      ],
    );
  }
}

class FoodSearchCategories extends StatelessWidget {
  const FoodSearchCategories({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final textTheme = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
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
                leading: FoodCategoryAvatar(category: category, size: 20),
                onTap: () => context.push(FoodRoutes.categoryOf(category.code)),
              ),
          ],
        ),
      ],
    );
  }
}
