import 'package:flutter/material.dart';

import '../../motion/dealgo_motion.dart';
import '../tokens/dealgo_tokens.dart';
import 'dealgo_haptics.dart';

/// Gradient primary CTA from the mockups (purple, trailing arrow optional).
///
/// Still a [FilledButton] underneath so focus, semantics and keyboard
/// activation come from Material; the gradient is painted behind it.
class DealGoPrimaryButton extends StatefulWidget {
  const DealGoPrimaryButton({
    required this.label,
    required this.onPressed,
    this.isLoading = false,
    this.enabled = true,
    this.trailingIcon,
    this.leadingIcon,
    this.haptic = true,
    super.key,
  });

  final String label;
  final VoidCallback onPressed;
  final bool isLoading;
  final bool enabled;
  final IconData? trailingIcon;
  final IconData? leadingIcon;
  final bool haptic;

  @override
  State<DealGoPrimaryButton> createState() => _DealGoPrimaryButtonState();
}

class _DealGoPrimaryButtonState extends State<DealGoPrimaryButton> {
  bool _pressed = false;

  bool get _canPress => widget.enabled && !widget.isLoading;

  void _setPressed(bool value) {
    if (_pressed != value && mounted) {
      setState(() => _pressed = value);
    }
  }

  @override
  Widget build(BuildContext context) {
    final reduced = DealGoMotion.prefersReducedMotion(context);
    final radius = BorderRadius.circular(DealGoRadius.button);
    final disabled = !widget.enabled;

    final button = FilledButton(
      onPressed: _canPress
          ? () {
              if (widget.haptic) {
                DealGoHaptics.tap();
              }
              widget.onPressed();
            }
          : null,
      style: ButtonStyle(
        animationDuration: Duration.zero,
        elevation: const WidgetStatePropertyAll(0),
        minimumSize: const WidgetStatePropertyAll(
          Size(DealGoDimensions.minTapTarget, DealGoDimensions.buttonMinHeight),
        ),
        padding: const WidgetStatePropertyAll(
          EdgeInsets.symmetric(horizontal: DealGoSpacing.s20),
        ),
        foregroundColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.disabled) && !widget.isLoading
              ? Colors.white.withValues(alpha: 0.9)
              : Colors.white,
        ),
        backgroundColor: const WidgetStatePropertyAll(Colors.transparent),
        overlayColor: WidgetStatePropertyAll(
          Colors.white.withValues(alpha: 0.08),
        ),
        shadowColor: const WidgetStatePropertyAll(Colors.transparent),
        shape: WidgetStatePropertyAll(
          RoundedRectangleBorder(borderRadius: radius),
        ),
        textStyle: const WidgetStatePropertyAll(
          TextStyle(
            fontFamily: DealGoTypography.fontFamily,
            fontSize: 16,
            height: 1.25,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      child: widget.isLoading
          ? Row(
              mainAxisAlignment: MainAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              children: [
                const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.4,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(width: DealGoSpacing.s12),
                Flexible(
                  child: Text(
                    widget.label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            )
          : _ButtonLabel(
              label: widget.label,
              leadingIcon: widget.leadingIcon,
              trailingIcon: widget.trailingIcon,
            ),
    );

    return Listener(
      onPointerDown: _canPress ? (_) => _setPressed(true) : null,
      onPointerUp: (_) => _setPressed(false),
      onPointerCancel: (_) => _setPressed(false),
      child: AnimatedScale(
        scale: _pressed && !reduced ? 0.98 : 1,
        duration: DealGoMotion.fast,
        curve: DealGoMotion.standard,
        child: DecoratedBox(
          decoration: BoxDecoration(
            borderRadius: radius,
            color: disabled
                ? DealGoColors.primary.withValues(alpha: 0.38)
                : (_pressed
                      ? DealGoColors.primaryPressed
                      : DealGoColors.primary),
            boxShadow: disabled || widget.isLoading
                ? null
                : DealGoShadows.button,
          ),
          child: button,
        ),
      ),
    );
  }
}

class _ButtonLabel extends StatelessWidget {
  const _ButtonLabel({
    required this.label,
    required this.leadingIcon,
    required this.trailingIcon,
  });

  final String label;
  final IconData? leadingIcon;
  final IconData? trailingIcon;

  @override
  Widget build(BuildContext context) {
    final labelText = Text(
      label,
      maxLines: 1,
      softWrap: false,
      overflow: TextOverflow.fade,
    );
    if (leadingIcon == null && trailingIcon == null) {
      return FittedBox(fit: BoxFit.scaleDown, child: labelText);
    }
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (leadingIcon != null) ...[
          Icon(leadingIcon, size: 18),
          const SizedBox(width: DealGoSpacing.s8),
        ],
        Flexible(child: FittedBox(fit: BoxFit.scaleDown, child: labelText)),
        if (trailingIcon != null) ...[
          const SizedBox(width: DealGoSpacing.s8),
          Icon(trailingIcon, size: 18),
        ],
      ],
    );
  }
}
