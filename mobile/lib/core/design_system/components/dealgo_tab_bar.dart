import 'package:flutter/material.dart';

import '../tokens/dealgo_tokens.dart';

class DealGoTabDestination {
  const DealGoTabDestination({
    required this.label,
    required this.icon,
    required this.selectedIcon,
  });

  final String label;
  final IconData icon;
  final IconData selectedIcon;
}

/// Standard role bottom nav (merchant / driver). Customer elevated “Đặt” stays
/// in [CustomerTabBar] — Material Icons are temporary until brand tab assets land.
class DealGoTabBar extends StatelessWidget {
  const DealGoTabBar({
    required this.destinations,
    required this.selectedIndex,
    required this.onDestinationSelected,
    super.key,
  });

  final List<DealGoTabDestination> destinations;
  final int selectedIndex;
  final ValueChanged<int> onDestinationSelected;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        color: DealGoColors.card,
        border: Border(top: BorderSide(color: DealGoColors.border)),
      ),
      child: NavigationBar(
        selectedIndex: selectedIndex,
        onDestinationSelected: onDestinationSelected,
        backgroundColor: DealGoColors.card,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        shadowColor: Colors.transparent,
        indicatorColor: DealGoColors.subtlePurple,
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
        destinations: [
          for (final tab in destinations)
            NavigationDestination(
              icon: Icon(tab.icon, color: DealGoColors.textSecondary),
              selectedIcon: Icon(tab.selectedIcon, color: DealGoColors.primary),
              label: tab.label,
            ),
        ],
      ),
    );
  }
}
