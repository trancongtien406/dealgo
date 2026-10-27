import 'package:flutter/material.dart';

import '../tokens/dealgo_tokens.dart';
import 'dealgo_haptics.dart';

/// Outlined purple secondary action (mockup footers: "Quay lại", "Hủy").
class DealGoSecondaryButton extends StatelessWidget {
  const DealGoSecondaryButton({
    required this.label,
    required this.onPressed,
    this.enabled = true,
    this.leadingIcon,
    this.tone = DealGoSecondaryTone.brand,
    this.compact = false,
    super.key,
  });

  final String label;
  final VoidCallback onPressed;
  final bool enabled;
  final IconData? leadingIcon;
  final DealGoSecondaryTone tone;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final color = tone == DealGoSecondaryTone.danger
        ? DealGoColors.danger
        : DealGoColors.primary;
    final text = Text(
      label,
      textAlign: TextAlign.center,
      maxLines: 2,
      overflow: TextOverflow.ellipsis,
    );
    return OutlinedButton(
      onPressed: enabled
          ? () {
              DealGoHaptics.selection();
              onPressed();
            }
          : null,
      style: ButtonStyle(
        animationDuration: Duration.zero,
        elevation: const WidgetStatePropertyAll(0),
        minimumSize: WidgetStatePropertyAll(
          Size(
            DealGoDimensions.minTapTarget,
            compact ? 48 : DealGoDimensions.buttonMinHeight,
          ),
        ),
        padding: WidgetStatePropertyAll(
          EdgeInsets.symmetric(
            horizontal: compact ? DealGoSpacing.s12 : DealGoSpacing.s16,
          ),
        ),
        foregroundColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.disabled)
              ? color.withValues(alpha: 0.4)
              : color,
        ),
        backgroundColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.pressed)
              ? DealGoColors.subtlePurple
              : DealGoColors.card,
        ),
        side: WidgetStateProperty.resolveWith(
          (states) => BorderSide(
            color: states.contains(WidgetState.disabled)
                ? color.withValues(alpha: 0.3)
                : color,
            width: 1.4,
          ),
        ),
        shape: WidgetStatePropertyAll(
          RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(DealGoRadius.button),
          ),
        ),
        textStyle: const WidgetStatePropertyAll(
          TextStyle(
            fontFamily: DealGoTypography.fontFamily,
            fontSize: 15,
            height: 1.25,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      child: leadingIcon == null
          ? text
          : Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(leadingIcon, size: 18),
                const SizedBox(width: DealGoSpacing.s8),
                Flexible(child: text),
              ],
            ),
    );
  }
}

enum DealGoSecondaryTone { brand, danger }
