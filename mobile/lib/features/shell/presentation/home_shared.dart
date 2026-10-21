import 'package:flutter/material.dart';

import '../../../core/design_system/tokens/dealgo_tokens.dart';
import '../../../core/design_system/icons/dealgo_icons.dart';

class HomePillButton extends StatelessWidget {
  const HomePillButton({
    required this.label,
    required this.onPressed,
    this.expanded = false,
    super.key,
  });

  final String label;
  final VoidCallback onPressed;
  final bool expanded;

  @override
  Widget build(BuildContext context) {
    final button = FilledButton(
      onPressed: onPressed,
      style: FilledButton.styleFrom(
        backgroundColor: DealGoColors.primary,
        foregroundColor: Colors.white,
        elevation: 0,
        minimumSize: Size(expanded ? double.infinity : 0, 36),
        padding: const EdgeInsets.symmetric(horizontal: DealGoSpacing.s16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
        textStyle: const TextStyle(
          fontFamily: DealGoTypography.fontFamily,
          fontSize: 14,
          fontWeight: FontWeight.w700,
        ),
      ),
      child: Row(
        mainAxisSize: expanded ? MainAxisSize.max : MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(width: DealGoSpacing.s4),
          const Icon(DealGoIcons.arrowRight, size: 16),
        ],
      ),
    );
    if (!expanded) {
      return button;
    }
    return SizedBox(width: double.infinity, child: button);
  }
}

/// Compact outlined CTA used on the C001 voucher strip.
class HomeOutlinePillButton extends StatelessWidget {
  const HomeOutlinePillButton({
    required this.label,
    required this.onPressed,
    super.key,
  });

  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return OutlinedButton(
      onPressed: onPressed,
      style: OutlinedButton.styleFrom(
        foregroundColor: DealGoColors.primary,
        side: const BorderSide(color: DealGoColors.primary, width: 1.4),
        minimumSize: const Size(0, 36),
        padding: const EdgeInsets.symmetric(horizontal: DealGoSpacing.s12),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
        textStyle: const TextStyle(
          fontFamily: DealGoTypography.fontFamily,
          fontSize: 13,
          fontWeight: FontWeight.w700,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(label),
          const SizedBox(width: DealGoSpacing.s4),
          const Icon(DealGoIcons.arrowRight, size: 14),
        ],
      ),
    );
  }
}
