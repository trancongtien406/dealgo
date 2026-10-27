import 'package:flutter/material.dart';

import '../tokens/dealgo_tokens.dart';

/// Visual gap between neighbouring chat / call circles.
const double dealgoContactGap = 12;

/// Diameter of a chat / call circle: never below the 44 pt touch minimum.
const double dealgoContactSize = 46;

/// Round chat / call button used on trip contact rows.
///
/// [filled] = solid [color] with a white glyph (call); otherwise a soft tinted
/// circle with a thin border and a [color] glyph (chat).
class DealGoContactButton extends StatelessWidget {
  const DealGoContactButton({
    required this.icon,
    required this.tooltip,
    required this.onPressed,
    this.filled = false,
    this.color = DealGoColors.primary,
    super.key,
  });

  /// Usually an [Icon]; may be wrapped in an unread badge.
  final Widget icon;
  final String tooltip;
  final VoidCallback? onPressed;
  final bool filled;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final enabled = onPressed != null;
    final bg = filled ? color : DealGoColors.subtlePurple;
    final fg = filled ? Colors.white : color;
    return Semantics(
      button: true,
      enabled: enabled,
      label: tooltip,
      child: Tooltip(
        message: tooltip,
        child: SizedBox.square(
          dimension: dealgoContactSize,
          child: Material(
            color: enabled ? bg : bg.withValues(alpha: 0.45),
            shape: CircleBorder(
              side: filled
                  ? BorderSide.none
                  : BorderSide(color: color.withValues(alpha: 0.22)),
            ),
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              onTap: onPressed,
              child: Center(
                child: IconTheme.merge(
                  data: IconThemeData(color: fg, size: 22),
                  child: icon,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Chat / call circles spaced [dealgoContactGap] apart.
class DealGoContactActions extends StatelessWidget {
  const DealGoContactActions({required this.children, super.key});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      for (var i = 0; i < children.length; i++) ...[
        if (i > 0) const SizedBox(width: dealgoContactGap),
        children[i],
      ],
    ],
  );
}
