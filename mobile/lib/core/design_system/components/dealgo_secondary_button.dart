import 'package:flutter/material.dart';

import '../tokens/dealgo_tokens.dart';

class DealGoSecondaryButton extends StatelessWidget {
  const DealGoSecondaryButton({
    required this.label,
    required this.onPressed,
    this.enabled = true,
    super.key,
  });

  final String label;
  final VoidCallback onPressed;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    return OutlinedButton(
      onPressed: enabled ? onPressed : null,
      style: ButtonStyle(
        animationDuration: Duration.zero,
        elevation: const WidgetStatePropertyAll(0),
        minimumSize: const WidgetStatePropertyAll(
          Size(DealGoDimensions.minTapTarget, DealGoDimensions.buttonMinHeight),
        ),
        padding: const WidgetStatePropertyAll(
          EdgeInsets.symmetric(horizontal: DealGoSpacing.s16),
        ),
        foregroundColor: const WidgetStatePropertyAll(DealGoColors.primary),
        backgroundColor: const WidgetStatePropertyAll(DealGoColors.card),
        side: const WidgetStatePropertyAll(
          BorderSide(color: DealGoColors.primary, width: 1.4),
        ),
        shape: WidgetStatePropertyAll(
          RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(DealGoRadius.button),
          ),
        ),
        textStyle: const WidgetStatePropertyAll(
          TextStyle(fontSize: 15, height: 1.25, fontWeight: FontWeight.w600),
        ),
      ),
      child: Text(label, textAlign: TextAlign.center),
    );
  }
}
