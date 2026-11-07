import 'package:flutter/material.dart';

import '../../../core/design_system/tokens/dealgo_tokens.dart';

/// Filter pill styled consistently with [FoodFilterPill] (rounded-rect border,
/// subtle purple active tint).
class AccountFilterChip extends StatelessWidget {
  const AccountFilterChip({
    required this.label,
    required this.selected,
    required this.onSelected,
    this.icon,
    super.key,
  });

  final String label;
  final bool selected;
  final VoidCallback onSelected;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final background = selected ? DealGoColors.subtlePurple : DealGoColors.card;
    final borderColor = selected ? DealGoColors.primary : DealGoColors.border;
    final foreground = selected
        ? DealGoColors.primary
        : DealGoColors.textSecondary;
    final borderRadius = BorderRadius.circular(DealGoRadius.small);
    final shape = RoundedRectangleBorder(
      borderRadius: borderRadius,
      side: BorderSide(color: borderColor, width: selected ? 1.2 : 1),
    );

    final content = ConstrainedBox(
      constraints: const BoxConstraints(minHeight: 34),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: DealGoSpacing.s12,
          vertical: DealGoSpacing.s6,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Icon(icon, size: 14, color: foreground),
              const SizedBox(width: DealGoSpacing.s6),
            ],
            Text(
              label,
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                color: foreground,
                fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );

    return Semantics(
      label: label,
      button: true,
      selected: selected,
      child: Material(
        color: background,
        shape: shape,
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onSelected,
          child: content,
        ),
      ),
    );
  }
}

class AccountSectionHeader extends StatelessWidget {
  const AccountSectionHeader({required this.title, this.action, super.key});

  final String title;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(title, style: Theme.of(context).textTheme.titleMedium),
        ),
        ?action,
      ],
    );
  }
}

class AccountLinkText extends StatelessWidget {
  const AccountLinkText(this.label, {super.key});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Text(
      label,
      style: Theme.of(context).textTheme.labelSmall?.copyWith(
        color: DealGoColors.primary,
        fontWeight: FontWeight.w600,
        fontSize: 14,
      ),
    );
  }
}

class AccountToneIcon extends StatelessWidget {
  const AccountToneIcon({
    required this.icon,
    required this.background,
    required this.foreground,
    super.key,
  });

  final IconData icon;
  final Color background;
  final Color foreground;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 40,
      height: 40,
      alignment: Alignment.center,
      decoration: BoxDecoration(color: background, shape: BoxShape.circle),
      child: Icon(icon, color: foreground, size: 22),
    );
  }
}
