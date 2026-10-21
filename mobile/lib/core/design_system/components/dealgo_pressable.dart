import 'package:flutter/material.dart';

import '../../motion/dealgo_motion.dart';
import 'dealgo_haptics.dart';

/// Press feedback (subtle scale-down) for custom tappable surfaces.
///
/// Keeps a 48dp hit area via [minSize] and exposes button semantics. Scale is
/// skipped when the platform requests reduced motion.
class DealGoPressable extends StatefulWidget {
  const DealGoPressable({
    required this.child,
    required this.onTap,
    this.semanticLabel,
    this.haptic = true,
    this.enabled = true,
    this.pressedScale = 0.97,
    this.minSize = const Size(48, 48),
    super.key,
  });

  final Widget child;
  final VoidCallback? onTap;
  final String? semanticLabel;
  final bool haptic;
  final bool enabled;
  final double pressedScale;
  final Size minSize;

  @override
  State<DealGoPressable> createState() => _DealGoPressableState();
}

class _DealGoPressableState extends State<DealGoPressable> {
  bool _pressed = false;

  bool get _active => widget.enabled && widget.onTap != null;

  void _setPressed(bool value) {
    if (!_active || _pressed == value) {
      return;
    }
    setState(() => _pressed = value);
  }

  @override
  Widget build(BuildContext context) {
    final reduced = DealGoMotion.prefersReducedMotion(context);
    return Semantics(
      button: true,
      enabled: _active,
      label: widget.semanticLabel,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapDown: (_) => _setPressed(true),
        onTapCancel: () => _setPressed(false),
        onTapUp: (_) => _setPressed(false),
        onTap: _active
            ? () {
                if (widget.haptic) {
                  DealGoHaptics.tap();
                }
                widget.onTap!();
              }
            : null,
        child: ConstrainedBox(
          constraints: BoxConstraints(
            minWidth: widget.minSize.width,
            minHeight: widget.minSize.height,
          ),
          child: AnimatedScale(
            scale: _pressed && !reduced ? widget.pressedScale : 1,
            duration: DealGoMotion.fast,
            curve: DealGoMotion.standard,
            child: AnimatedOpacity(
              opacity: widget.enabled ? 1 : 0.5,
              duration: DealGoMotion.fast,
              child: widget.child,
            ),
          ),
        ),
      ),
    );
  }
}
