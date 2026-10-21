import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/design_system/tokens/dealgo_tokens.dart';
import '../../../l10n/app_localizations.dart';
import 'shell_tab.dart';

/// Comfort inset under the last scroll item (Scaffold already clears the bar).
double customerShellBottomClearance(
  BuildContext context, {
  double extra = DealGoSpacing.s16,
}) {
  return extra;
}

/// Customer bottom nav. The selected tab is a static plate, not a sliding one.
class CustomerTabBar extends StatelessWidget {
  const CustomerTabBar({
    required this.navigationShell,
    required this.tabs,
    super.key,
  });

  final StatefulNavigationShell navigationShell;
  final List<ShellTab> tabs;

  static const double barHeight = 64;
  static const double orbSize = 44;
  /// Kept for call sites that still add overhang; flat bar has none.
  static const double orbOverhang = 0;

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.paddingOf(context).bottom;
    final textTheme = Theme.of(context).textTheme;
    final l10n = AppLocalizations.of(context);
    final selected = navigationShell.currentIndex.clamp(0, tabs.length - 1);

    return Material(
      color: DealGoColors.card,
      elevation: 0,
      shadowColor: Colors.transparent,
      child: DecoratedBox(
        decoration: const BoxDecoration(
          border: Border(top: BorderSide(color: DealGoColors.border)),
          boxShadow: [
            BoxShadow(
              color: Color(0x0F0F172A),
              blurRadius: 12,
              offset: Offset(0, -2),
            ),
          ],
        ),
        child: SizedBox(
          height: barHeight + bottom,
          child: Padding(
            padding: EdgeInsets.only(bottom: bottom),
            child: Row(
              children: [
                for (var i = 0; i < tabs.length; i++)
                  Expanded(
                    child: _TabItem(
                      label: tabs[i].localizedLabel(l10n),
                      icon: selected == i
                          ? tabs[i].selectedIcon
                          : tabs[i].icon,
                      selected: selected == i,
                      textTheme: textTheme,
                      onTap: () => navigationShell.goBranch(i),
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

class _TabItem extends StatelessWidget {
  const _TabItem({
    required this.label,
    required this.icon,
    required this.selected,
    required this.textTheme,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final bool selected;
  final TextTheme textTheme;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = selected ? DealGoColors.primary : DealGoColors.textSecondary;
    return Semantics(
      button: true,
      selected: selected,
      label: label,
      child: InkWell(
        onTap: onTap,
        splashColor: Colors.transparent,
        highlightColor: Colors.transparent,
        child: ExcludeSemantics(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: selected
                    ? DealGoColors.subtlePurple
                    : Colors.transparent,
                borderRadius: BorderRadius.circular(DealGoRadius.input),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(icon, size: 22, color: color),
                  const SizedBox(height: 2),
                  Text(
                    label,
                    maxLines: 1,
                    softWrap: false,
                    overflow: TextOverflow.fade,
                    style: (textTheme.labelSmall ?? const TextStyle()).copyWith(
                      color: color,
                      fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                      fontSize: 11,
                      height: 1.1,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
