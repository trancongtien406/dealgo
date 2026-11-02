import 'dart:ui';

import 'package:flutter/material.dart';

import '../tokens/dealgo_tokens.dart';

/// Frosted sticky footer for primary/secondary CTAs.
///
/// Pair with `Scaffold(extendBody: true, bottomNavigationBar: DealGoBottomBar(...))`
/// so list content can scroll underneath the bar.
class DealGoBottomBar extends StatelessWidget {
  const DealGoBottomBar({
    required this.child,
    this.frosted = true,
    this.padding,
    super.key,
  });

  /// Typically a [DealGoPrimaryButton], or a Row of primary + secondary.
  final Widget child;

  /// Soft blur + translucent card surface. Disable for solid opaque bars.
  final bool frosted;

  final EdgeInsetsGeometry? padding;

  @override
  Widget build(BuildContext context) {
    final content = SafeArea(
      top: false,
      child: Padding(
        padding:
            padding ??
            const EdgeInsets.fromLTRB(
              DealGoDimensions.pageGutter,
              DealGoSpacing.s12,
              DealGoDimensions.pageGutter,
              DealGoSpacing.s12,
            ),
        child: child,
      ),
    );

    final surface = DecoratedBox(
      decoration: BoxDecoration(
        color: DealGoColors.card.withValues(alpha: frosted ? 0.88 : 1),
        boxShadow: DealGoShadows.floating,
        border: Border(top: BorderSide(color: DealGoColors.divider)),
      ),
      child: content,
    );

    if (!frosted) return surface;

    return ClipRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
        child: surface,
      ),
    );
  }
}
