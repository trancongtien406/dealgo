import 'package:flutter/material.dart';

import '../../../../core/design_system/tokens/dealgo_tokens.dart';
import '../../../../core/design_system/tokens/dealgo_type_scale.dart';
import '../../../../l10n/app_localizations.dart';
import '../cubit/food_discovery_cubit.dart';

/// Bottom of a paginated store list: spinner, retry, or the end label.
class FoodFeedFooter extends StatelessWidget {
  const FoodFeedFooter({required this.state, required this.onRetry, super.key});

  final FoodDiscoveryReady? state;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final ready = state;
    if (ready == null || ready.stores.isEmpty) {
      return const SizedBox.shrink();
    }
    if (ready.isLoadingMore) {
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
    if (ready.loadMoreFailed) {
      return Center(
        child: TextButton(
          key: const Key('food-feed-retry'),
          onPressed: onRetry,
          child: Text(AppLocalizations.of(context).actionRetry),
        ),
      );
    }
    if (ready.hasMore) {
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
