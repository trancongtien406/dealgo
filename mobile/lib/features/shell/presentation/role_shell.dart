import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/design_system/components/dealgo_nav_insets.dart';
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
    final hideBar = customerBar && navigationShell.currentIndex == 2;
    return Scaffold(
      backgroundColor: DealGoColors.canvas,
      // The floating bar draws over the body: the active circle overlaps
      // content, the rest of the body ends at the pill top.
      extendBody: true,
      body: hideBar
          ? navigationShell
          : FloatingNavBody(
              // Read above the Scaffold: it strips viewInsets from the body.
              keyboardOpen: MediaQuery.viewInsetsOf(context).bottom > 0,
              child: navigationShell,
            ),
      // Five fixed-width tabs: cap text scaling so labels stay legible
      // instead of overflowing at accessibility sizes.
      bottomNavigationBar: hideBar
          ? null
          : MediaQuery.withClampedTextScaling(
              maxScaleFactor: kTabBarMaxTextScale,
              child: customerBar
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
            ),
    );
  }
}

/// Shell body under the floating [DealGoTabBar]: ends at the pill top and
/// hands pages a zero bottom padding (the bar already covers the system
/// inset). With the keyboard open the bar is hidden behind it, so no
/// clearance is added.
class FloatingNavBody extends StatelessWidget {
  const FloatingNavBody({
    required this.child,
    this.keyboardOpen = false,
    super.key,
  });

  final Widget child;
  final bool keyboardOpen;

  @override
  Widget build(BuildContext context) {
    final clearance = keyboardOpen
        ? 0.0
        : dealGoNavBarMetricsOf(context).contentClearance;
    return MediaQuery.removePadding(
      context: context,
      removeBottom: true,
      child: Padding(
        padding: EdgeInsets.only(bottom: clearance),
        child: child,
      ),
    );
  }
}

/// Max text scale for the bottom tab bar labels.
const double kTabBarMaxTextScale = 1.15;
