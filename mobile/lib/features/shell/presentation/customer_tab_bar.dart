import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/design_system/tokens/dealgo_tokens.dart';
import '../../../l10n/app_localizations.dart';
import 'shell_tab.dart';

/// Customer shell with elevated center “Đặt” orb (C001). Material icons are
/// temporary until brand tab assets are wired.
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
    final bottom = MediaQuery.paddingOf(context).bottom;
    final textTheme = Theme.of(context).textTheme;
    final l10n = AppLocalizations.of(context);

    return SizedBox(
      height: 108 + bottom,
      child: Stack(
        children: [
          Positioned(
            top: 30,
            left: 0,
            right: 0,
            bottom: 0,
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: DealGoColors.card,
                border: const Border(
                  top: BorderSide(color: DealGoColors.border),
                ),
                boxShadow: [
                  BoxShadow(
                    color: DealGoColors.text.withValues(alpha: 0.06),
                    blurRadius: 16,
                    offset: const Offset(0, -4),
                  ),
                ],
              ),
            ),
          ),
          Padding(
            padding: EdgeInsets.only(bottom: bottom, top: DealGoSpacing.s8),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                for (var index = 0; index < tabs.length; index++)
                  Expanded(
                    child: _TabSlot(
                      label: tabs[index].localizedLabel(l10n),
                      selected: navigationShell.currentIndex == index,
                      raised: index == 2,
                      icon: _iconFor(
                        index,
                        navigationShell.currentIndex == index,
                      ),
                      textTheme: textTheme,
                      onTap: () => navigationShell.goBranch(index),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

IconData _iconFor(int index, bool selected) {
  return switch (index) {
    0 => selected ? Icons.home_rounded : Icons.home_outlined,
    1 => selected ? Icons.place : Icons.place_outlined,
    2 => Icons.qr_code_scanner_rounded,
    3 => selected ? Icons.shopping_bag : Icons.shopping_bag_outlined,
    _ => selected ? Icons.person : Icons.person_outline,
  };
}

class _TabSlot extends StatelessWidget {
  const _TabSlot({
    required this.label,
    required this.selected,
    required this.raised,
    required this.icon,
    required this.textTheme,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final bool raised;
  final IconData icon;
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
        child: ExcludeSemantics(
          child: Padding(
            padding: const EdgeInsets.only(bottom: DealGoSpacing.s8),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                if (raised)
                  const _BookOrb()
                else
                  Icon(icon, color: color, size: 24),
                const SizedBox(height: DealGoSpacing.s4),
                Text(
                  label,
                  style: textTheme.labelSmall?.copyWith(
                    color: raised ? DealGoColors.primary : color,
                    fontWeight: selected || raised
                        ? FontWeight.w700
                        : FontWeight.w500,
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

class _BookOrb extends StatelessWidget {
  const _BookOrb();

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: DealGoColors.primary,
        boxShadow: [
          BoxShadow(
            color: DealGoColors.primary.withValues(alpha: 0.28),
            blurRadius: 12,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: const SizedBox(
        width: 56,
        height: 56,
        child: Icon(
          Icons.qr_code_scanner_rounded,
          color: Colors.white,
          size: 28,
        ),
      ),
    );
  }
}
