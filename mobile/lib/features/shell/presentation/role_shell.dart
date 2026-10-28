import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/design_system/components/dealgo_nav_insets.dart';
import '../../../core/design_system/components/dealgo_tab_bar.dart';
import '../../../core/design_system/tokens/dealgo_tokens.dart';
import '../../../l10n/app_localizations.dart';
import '../../inbox/presentation/inbox_unread.dart';
import 'customer_tab_bar.dart';
import 'shell_tab.dart';

class RoleShell extends StatefulWidget {
  const RoleShell({
    required this.navigationShell,
    required this.tabs,
    super.key,
  });

  final StatefulNavigationShell navigationShell;
  final List<ShellTab> tabs;

  @override
  State<RoleShell> createState() => _RoleShellState();
}

class _RoleShellState extends State<RoleShell> {
  StatefulNavigationShell get navigationShell => widget.navigationShell;
  List<ShellTab> get tabs => widget.tabs;

  bool get _customerBookBar =>
      tabs.length == 5 && tabs[2].path == '/customer/book';

  /// The inbox badge sits on the notifications tab (driver) or, without one,
  /// on the account tab whose header opens the inbox (merchant).
  bool _carriesInboxBadge(ShellTab tab) {
    final hasInboxTab = tabs.any(
      (t) => t.kind == ShellTabKind.driverNotifications,
    );
    return hasInboxTab
        ? tab.kind == ShellTabKind.driverNotifications
        : tab.kind == ShellTabKind.account;
  }

  @override
  void initState() {
    super.initState();
    if (!_customerBookBar) {
      attachInboxUnread(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final customerBar = _customerBookBar;
    // The app-wide bar stays on every tab, “Đặt xe” included; deeper ride
    // screens (fare, offers, tracking) are pushed above the shell instead.
    return Scaffold(
      backgroundColor: DealGoColors.canvas,
      // The floating bar draws over the body; content scrolls behind it.
      extendBody: true,
      body: FloatingNavBody(
        // Measured above the Scaffold: it strips the system inset and the
        // keyboard from the body's MediaQuery.
        coveredBottom: MediaQuery.viewInsetsOf(context).bottom > 0
            ? 0
            : dealGoNavBarMetricsOf(context).totalHeight,
        child: navigationShell,
      ),
      // Five fixed-width tabs: cap text scaling so labels stay legible
      // instead of overflowing at accessibility sizes.
      bottomNavigationBar: MediaQuery.withClampedTextScaling(
        maxScaleFactor: kTabBarMaxTextScale,
        child: customerBar
            ? CustomerTabBar(navigationShell: navigationShell, tabs: tabs)
            : ListenableBuilder(
                listenable: InboxUnread.instance,
                builder: (context, _) => DealGoTabBar(
                  selectedIndex: navigationShell.currentIndex,
                  onDestinationSelected: navigationShell.goBranch,
                  destinations: [
                    for (final tab in tabs)
                      DealGoTabDestination(
                        label: tab.localizedLabel(l10n),
                        icon: tab.icon,
                        selectedIcon: tab.selectedIcon,
                        badgeCount: _carriesInboxBadge(tab)
                            ? InboxUnread.instance.count
                            : 0,
                      ),
                  ],
                ),
              ),
      ),
    );
  }
}

/// Shell body under the floating [DealGoTabBar] (`extendBody`): pages draw
/// to the screen bottom and scroll behind the bar. [coveredBottom] (the bar's
/// full height, or 0 while the keyboard hides it) is handed down as
/// `MediaQuery.padding.bottom`, so [dealGoScrollPadding] and bottom
/// [SafeArea]s keep the last item / sticky buttons above it. Null (bar not
/// shown, e.g. full-screen “Đặt”) leaves the Scaffold's own insets.
class FloatingNavBody extends StatelessWidget {
  const FloatingNavBody({required this.child, this.coveredBottom, super.key});

  final Widget child;
  final double? coveredBottom;

  @override
  Widget build(BuildContext context) {
    final covered = coveredBottom;
    if (covered == null) return child;
    final media = MediaQuery.of(context);
    return MediaQuery(
      data: media.copyWith(padding: media.padding.copyWith(bottom: covered)),
      child: child,
    );
  }
}

/// Max text scale for the bottom tab bar labels.
const double kTabBarMaxTextScale = 1.15;
