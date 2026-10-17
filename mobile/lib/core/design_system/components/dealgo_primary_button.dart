import 'package:flutter/material.dart';

import '../tokens/dealgo_tokens.dart';

class DealGoPrimaryButton extends StatelessWidget {
  const DealGoPrimaryButton({
    required this.label,
    required this.onPressed,
    this.isLoading = false,
    this.enabled = true,
    this.trailingIcon,
    super.key,
  });

  final String label;
  final VoidCallback onPressed;
  final bool isLoading;
  final bool enabled;
  final IconData? trailingIcon;

  bool get _canPress => enabled && !isLoading;

  @override
  Widget build(BuildContext context) {
    return FilledButton(
      onPressed: _canPress ? onPressed : null,
      style: ButtonStyle(
        animationDuration: Duration.zero,
        elevation: const WidgetStatePropertyAll(0),
        minimumSize: const WidgetStatePropertyAll(
          Size(DealGoDimensions.minTapTarget, DealGoDimensions.buttonMinHeight),
        ),
        padding: const WidgetStatePropertyAll(
          EdgeInsets.symmetric(horizontal: DealGoSpacing.s20),
        ),
        foregroundColor: const WidgetStatePropertyAll(Colors.white),
        backgroundColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.disabled)) {
            return DealGoColors.primary.withValues(alpha: 0.38);
          }
          if (states.contains(WidgetState.pressed)) {
            return DealGoColors.primaryPressed;
          }
          return DealGoColors.primary;
        }),
        shape: WidgetStatePropertyAll(
          RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(DealGoRadius.button),
          ),
        ),
        textStyle: const WidgetStatePropertyAll(
          TextStyle(fontSize: 16, height: 1.25, fontWeight: FontWeight.w600),
        ),
      ),
      child: isLoading
          ? Row(
              mainAxisAlignment: MainAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              children: [
                const SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.4,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(width: DealGoSpacing.s12),
                Text(label),
              ],
            )
          : _ButtonLabel(label: label, trailingIcon: trailingIcon),
    );
  }
}

class _ButtonLabel extends StatelessWidget {
  const _ButtonLabel({required this.label, required this.trailingIcon});

  final String label;
  final IconData? trailingIcon;

  @override
  Widget build(BuildContext context) {
    final icon = trailingIcon;
    final labelText = Text(label, maxLines: 1, overflow: TextOverflow.ellipsis);
    if (icon == null) {
      return labelText;
    }
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      mainAxisSize: MainAxisSize.min,
      children: [
        Flexible(child: labelText),
        const SizedBox(width: DealGoSpacing.s8),
        Icon(icon, size: 18),
      ],
    );
  }
}
