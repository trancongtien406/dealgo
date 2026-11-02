import 'package:flutter/material.dart';

import '../tokens/dealgo_tokens.dart';

/// White rounded surface with a hairline border and soft purple shadow.
class DealGoCard extends StatelessWidget {
  const DealGoCard({
    required this.child,
    this.onTap,
    this.padding = const EdgeInsets.all(DealGoSpacing.s16),
    this.elevated = true,
    this.color,
    this.borderColor,
    this.borderWidth = 1,
    this.semanticLabel,
    super.key,
  });

  final Widget child;
  final VoidCallback? onTap;
  final EdgeInsetsGeometry padding;

  /// Soft shadow from the mockups. Off for nested / list-dense cards.
  final bool elevated;
  final Color? color;
  final Color? borderColor;
  final double borderWidth;
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(DealGoRadius.card);
    final fill = color ?? DealGoColors.card;
    final shape = RoundedRectangleBorder(
      borderRadius: radius,
      side: BorderSide(
        color: borderColor ?? DealGoColors.border,
        width: borderWidth,
      ),
    );

    final content = Padding(padding: padding, child: child);

    final card = Material(
      color: fill,
      shape: shape,
      clipBehavior: Clip.antiAlias,
      child: onTap == null
          ? content
          : InkWell(onTap: onTap, customBorder: shape, child: content),
    );

    final decorated = elevated
        ? DecoratedBox(
            decoration: BoxDecoration(
              borderRadius: radius,
              boxShadow: DealGoShadows.card,
            ),
            child: card,
          )
        : card;

    if (semanticLabel == null) {
      return decorated;
    }
    return Semantics(
      label: semanticLabel,
      button: onTap != null,
      container: true,
      child: decorated,
    );
  }
}
