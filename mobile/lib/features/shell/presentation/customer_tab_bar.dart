import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/design_system/components/dealgo_tab_bar.dart';
import '../../../core/design_system/tokens/dealgo_tokens.dart';
import '../../../l10n/app_localizations.dart';
import 'shell_tab.dart';

/// Comfort inset under the last scroll item (`RoleShell` already clears the
/// floating bar).
double customerShellBottomClearance(
  BuildContext context, {
  double extra = DealGoSpacing.s16,
}) {
  return extra;
}

/// Customer bottom nav: the shared floating [DealGoTabBar] bound to the
/// customer shell branches. `RoleShell` hides it on “Đặt” (full-screen booking).
class CustomerTabBar extends StatelessWidget {
  const CustomerTabBar({
    required this.navigationShell,
    required this.tabs,
    super.key,
  });

  final StatefulNavigationShell navigationShell;
  final List<ShellTab> tabs;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return DealGoTabBar(
      selectedIndex: navigationShell.currentIndex,
      onDestinationSelected: navigationShell.goBranch,
      destinations: [
        for (final tab in tabs)
          DealGoTabDestination(
            label: tab.localizedLabel(l10n),
            icon: tab.icon,
            selectedIcon: tab.selectedIcon,
          ),
      ],
    );
  }
}
