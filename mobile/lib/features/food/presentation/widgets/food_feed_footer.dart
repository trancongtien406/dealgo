import 'package:flutter/material.dart';

import '../../../../core/design_system/tokens/dealgo_tokens.dart';
import '../../../../core/design_system/tokens/dealgo_type_scale.dart';
import '../../../../l10n/app_localizations.dart';
import '../cubit/food_discovery_cubit.dart';

/// Bottom of a paginated list: spinner, retry, or the end label.
class FoodFeedFooter extends StatelessWidget {
  FoodFeedFooter({
    required FoodDiscoveryReady? state,
    required this.onRetry,
    super.key,
  }) : hasRows = state != null && state.stores.isNotEmpty,
       isLoadingMore = state?.isLoadingMore ?? false,
       loadMoreFailed = state?.loadMoreFailed ?? false,
       hasMore = state?.hasMore ?? false,
       isRefreshing = state?.isRefreshing ?? false;

  /// Same footer for lists outside [FoodDiscoveryReady] (e.g. search results).
  const FoodFeedFooter.paged({
    required this.hasRows,
    required this.isLoadingMore,
    required this.loadMoreFailed,
    required this.hasMore,
    required this.isRefreshing,
    required this.onRetry,
    super.key,
  });

  final bool hasRows;
  final bool isLoadingMore;
  final bool loadMoreFailed;
  final bool hasMore;
  final bool isRefreshing;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    if (!hasRows) {
      return const SizedBox.shrink();
    }
    if (isLoadingMore) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: DealGoSpacing.s12),
        child: Center(
          child: SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
        ),
      );
    }
    if (loadMoreFailed) {
      return Center(
        child: TextButton(
          key: const Key('food-feed-retry'),
          onPressed: onRetry,
          child: Text(AppLocalizations.of(context).actionRetry),
        ),
      );
    }
    if (hasMore || isRefreshing) {
      return const SizedBox.shrink();
    }
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: DealGoSpacing.s12),
      child: Text(
        AppLocalizations.of(context).foodFeedEndOfList,
        key: const Key('food-feed-end'),
        textAlign: TextAlign.center,
        style: DealGoType.meta(Theme.of(context).textTheme)
            .copyWith(color: DealGoColors.textTertiary),
      ),
    );
  }
}
