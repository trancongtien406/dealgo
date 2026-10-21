import 'package:flutter/material.dart';

import '../tokens/dealgo_tokens.dart';

enum DealGoBadgeTone { brand, green, amber, danger, info, neutral }

/// Tinted rounded-square icon container used across mockup list rows.
class DealGoIconBadge extends StatelessWidget {
  const DealGoIconBadge(
    this.icon, {
    this.tone = DealGoBadgeTone.brand,
    this.size = DealGoDimensions.iconBadge,
    this.circle = false,
    super.key,
  });

  final IconData icon;
  final DealGoBadgeTone tone;
  final double size;
  final bool circle;

  @override
  Widget build(BuildContext context) {
    final (bg, fg) = switch (tone) {
      DealGoBadgeTone.brand => (
        DealGoColors.subtlePurple,
        DealGoColors.primary,
      ),
      DealGoBadgeTone.green => (
        DealGoColors.greenSurface,
        DealGoColors.brandGreen,
      ),
      DealGoBadgeTone.amber => (DealGoColors.amberSurface, DealGoColors.amber),
      DealGoBadgeTone.danger => (
        DealGoColors.dangerSurface,
        DealGoColors.danger,
      ),
      DealGoBadgeTone.info => (DealGoColors.infoSurface, DealGoColors.info),
      DealGoBadgeTone.neutral => (
        DealGoColors.divider,
        DealGoColors.textSecondary,
      ),
    };
    return ExcludeSemantics(
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: bg,
          shape: circle ? BoxShape.circle : BoxShape.rectangle,
          borderRadius: circle ? null : BorderRadius.circular(size * 0.3),
        ),
        alignment: Alignment.center,
        child: Icon(icon, size: size * 0.5, color: fg),
      ),
    );
  }
}
