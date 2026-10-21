import 'package:flutter/material.dart';

import '../../../core/design_system/components/dealgo_chip.dart';
import '../../../core/design_system/tokens/dealgo_tokens.dart';

/// Prefer [DealGoSegmentedControl] for exclusive filter rows; kept for
/// one-off filter pills that are not part of a segment group.
class AccountFilterChip extends StatelessWidget {
  const AccountFilterChip({
    required this.label,
    required this.selected,
    required this.onSelected,
    super.key,
  });

  final String label;
  final bool selected;
  final VoidCallback onSelected;

  @override
  Widget build(BuildContext context) {
    return DealGoChip(
      label: label,
      size: DealGoChipSize.md,
      selected: selected,
      onTap: onSelected,
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

