import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/design_system/components/dealgo_tab_bar.dart';
import '../../../core/design_system/tokens/dealgo_tokens.dart';
import '../../../l10n/app_localizations.dart';
import 'customer_tab_bar.dart';
import 'shell_tab.dart';

class RoleShell extends StatelessWidget {
  const RoleShell({
    required this.navigationShell,
    required this.tabs,
    super.key,
  });

  final StatefulNavigationShell navigationShell;
  final List<ShellTab> tabs;

  bool get _customerBookBar =>
      tabs.length == 5 && tabs[2].path == '/customer/book';

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final customerBar = _customerBookBar;
    // Full-screen booking — hide shell chrome while on “Đặt”.
    final hideCustomerBar =
        customerBar && navigationShell.currentIndex == 2;
    return Scaffold(
      backgroundColor: DealGoColors.canvas,
      body: navigationShell,
      bottomNavigationBar: hideCustomerBar
          ? null
          : customerBar
          ? CustomerTabBar(navigationShell: navigationShell, tabs: tabs)
          : DealGoTabBar(
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
            ),
    );
  }
}
