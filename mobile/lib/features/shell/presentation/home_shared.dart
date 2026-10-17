import 'package:flutter/material.dart';

import '../../../core/design_system/tokens/dealgo_tokens.dart';

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
        textStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
      ),
      child: Row(
        mainAxisSize: expanded ? MainAxisSize.max : MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(label),
          const SizedBox(width: DealGoSpacing.s4),
          const Icon(Icons.arrow_forward, size: 16),
        ],
      ),
    );
    if (!expanded) {
      return button;
    }
    return SizedBox(width: double.infinity, child: button);
  }
}
