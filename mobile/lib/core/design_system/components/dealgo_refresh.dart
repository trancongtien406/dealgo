import 'package:flutter/material.dart';

import '../tokens/dealgo_tokens.dart';
import 'dealgo_haptics.dart';

/// Brand pull-to-refresh. Child must be scrollable (use
/// `AlwaysScrollableScrollPhysics` so short/empty lists can still be pulled).
class DealGoRefresh extends StatelessWidget {
  const DealGoRefresh({
    required this.onRefresh,
    required this.child,
    super.key,
  });

  final Future<void> Function() onRefresh;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator.adaptive(
      color: DealGoColors.primary,
      backgroundColor: DealGoColors.card,
      onRefresh: () {
        DealGoHaptics.selection();
        return onRefresh();
      },
      child: child,
    );
  }
}
