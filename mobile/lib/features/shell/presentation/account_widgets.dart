import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/design_system/components/dealgo_chip.dart';
import '../../../core/design_system/tokens/dealgo_tokens.dart';
import '../../identity/presentation/widgets/auth_widgets.dart';

class AccountScreenHeader extends StatelessWidget {
  const AccountScreenHeader({
    required this.title,
    this.subtitle,
    this.trailing,
    super.key,
  });

  final String title;
  final String? subtitle;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Material(
      color: DealGoColors.card,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          DealGoSpacing.s8,
          DealGoSpacing.s8,
          DealGoSpacing.s8,
          DealGoSpacing.s8,
        ),
        child: Row(
          children: [
            AuthBackButton(
              onPressed: () {
                if (context.canPop()) {
                  context.pop();
                }
              },
            ),
            const SizedBox(width: DealGoSpacing.s8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: textTheme.titleMedium),
                  if (subtitle != null)
                    Text(subtitle!, style: textTheme.bodySmall),
                ],
              ),
            ),
            ?trailing,
          ],
        ),
      ),
    );
  }
}

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

InputDecoration accountFieldDecoration(
  BuildContext context, {
  required String hint,
  Widget? prefix,
  Widget? suffix,
}) {
  final border = OutlineInputBorder(
    borderRadius: BorderRadius.circular(DealGoRadius.input),
    borderSide: const BorderSide(color: DealGoColors.border),
  );
  return InputDecoration(
    hintText: hint,
    hintStyle: Theme.of(context).textTheme.bodyMedium
        ?.copyWith(color: DealGoColors.textSecondary),
    filled: true,
    fillColor: DealGoColors.card,
    prefixIcon: prefix,
    suffixIcon: suffix,
    contentPadding: const EdgeInsets.symmetric(vertical: DealGoSpacing.s12),
    enabledBorder: border,
    focusedBorder: border.copyWith(
      borderSide: const BorderSide(color: DealGoColors.primary, width: 1.4),
    ),
    border: border,
  );
}
