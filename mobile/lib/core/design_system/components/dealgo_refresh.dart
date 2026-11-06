import 'package:flutter/material.dart';

import '../../ui/keyboard_dismiss.dart';
import '../tokens/dealgo_tokens.dart';
import 'dealgo_haptics.dart';

/// Default predicate for [DealGoRefresh]: accepts vertical scroll notifications
/// from the root scroll view (`depth == 0`) or the body of a `NestedScrollView`
/// (`depth == 1`) so pull-to-refresh works across both standard lists and
/// nested scroll layouts.
bool dealGoRefreshNotificationPredicate(ScrollNotification notification) {
  return notification.metrics.axis == Axis.vertical && notification.depth <= 1;
}

class _AlwaysScrollableRefreshBehavior extends DealGoScrollBehavior {
  const _AlwaysScrollableRefreshBehavior();

  @override
  ScrollPhysics getScrollPhysics(BuildContext context) {
    return AlwaysScrollableScrollPhysics(
      parent: super.getScrollPhysics(context),
    );
  }
}

/// Brand pull-to-refresh. Automatically configures vertical scrollables with
/// [AlwaysScrollableScrollPhysics] so short or empty lists can always be pulled.
class DealGoRefresh extends StatelessWidget {
  const DealGoRefresh({
    required this.onRefresh,
    required this.child,
    this.notificationPredicate = dealGoRefreshNotificationPredicate,
    super.key,
  });

  final Future<void> Function() onRefresh;
  final Widget child;
  final ScrollNotificationPredicate notificationPredicate;

  @override
  Widget build(BuildContext context) {
    return ScrollConfiguration(
      behavior: const _AlwaysScrollableRefreshBehavior(),
      child: RefreshIndicator(
        color: DealGoColors.primary,
        backgroundColor: DealGoColors.card,
        strokeWidth: 2.5,
        notificationPredicate: notificationPredicate,
        onRefresh: () {
          DealGoHaptics.selection();
          return onRefresh();
        },
        child: child,
      ),
    );
  }
}
