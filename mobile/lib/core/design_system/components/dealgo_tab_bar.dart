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

/// Role bottom nav. The selected tab is a static plate, not a sliding one.
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

  static const double barHeight = 64;

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.paddingOf(context).bottom;
    final selected = selectedIndex.clamp(0, destinations.length - 1);
    final textTheme = Theme.of(context).textTheme;

    return Material(
      color: DealGoColors.card,
      child: DecoratedBox(
        decoration: const BoxDecoration(
          border: Border(top: BorderSide(color: DealGoColors.border)),
        ),
        child: SizedBox(
          height: barHeight + bottom,
          child: Padding(
            padding: EdgeInsets.only(bottom: bottom),
            child: Row(
              children: [
                for (var i = 0; i < destinations.length; i++)
                  Expanded(
                    child: InkWell(
                      onTap: () => onDestinationSelected(i),
                      splashColor: Colors.transparent,
                      highlightColor: Colors.transparent,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 6,
                        ),
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            color: selected == i
                                ? DealGoColors.subtlePurple
                                : Colors.transparent,
                            borderRadius: BorderRadius.circular(
                              DealGoRadius.input,
                            ),
                          ),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                selected == i
                                    ? destinations[i].selectedIcon
                                    : destinations[i].icon,
                                size: 22,
                                color: selected == i
                                    ? DealGoColors.primary
                                    : DealGoColors.textSecondary,
                              ),
                              const SizedBox(height: 2),
                              Text(
                                destinations[i].label,
                                maxLines: 1,
                                softWrap: false,
                                overflow: TextOverflow.fade,
                                style: textTheme.labelSmall?.copyWith(
                                  color: selected == i
                                      ? DealGoColors.primary
                                      : DealGoColors.textSecondary,
                                  fontWeight: selected == i
                                      ? FontWeight.w700
                                      : FontWeight.w500,
                                  fontSize: 11,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
