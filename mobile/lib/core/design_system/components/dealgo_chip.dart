import 'package:flutter/material.dart';

import '../tokens/dealgo_tokens.dart';

enum DealGoChipTone { neutral, brand, success, warning, danger, promo }

enum DealGoChipSize { sm, md }

/// Status/meta pill. Color alone is never enough — [label] is required.
class DealGoChip extends StatelessWidget {
  const DealGoChip({
    required this.label,
    this.tone = DealGoChipTone.neutral,
    this.size = DealGoChipSize.sm,
    this.leading,
    this.selected = false,
    this.enabled = true,
    this.onTap,
    super.key,
  });

  final String label;
  final DealGoChipTone tone;
  final DealGoChipSize size;
  final Widget? leading;
  final bool selected;
  final bool enabled;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final colors = _colors(tone, selected: selected);
    final vertical = size == DealGoChipSize.sm
        ? DealGoSpacing.s4
        : DealGoSpacing.s8;
    final horizontal = size == DealGoChipSize.sm
        ? DealGoSpacing.s8
        : DealGoSpacing.s12;
    final shape = StadiumBorder(
      side: BorderSide(color: selected ? DealGoColors.primary : colors.border),
    );

    // Flexible + ellipsis: chips often sit in tight Rows (offer cards, receipts).
    final labelRow = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (leading != null) ...[
          leading!,
          const SizedBox(width: DealGoSpacing.s4),
        ],
        Flexible(
          child: Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: enabled
                  ? colors.foreground
                  : colors.foreground.withValues(alpha: 0.5),
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ],
    );

    final content = Padding(
      padding: EdgeInsets.symmetric(horizontal: horizontal, vertical: vertical),
      child: labelRow,
    );

    final painted = Material(
      color: enabled
          ? colors.background
          : colors.background.withValues(alpha: 0.55),
      shape: shape,
      child: onTap == null || !enabled
          ? content
          : InkWell(
              onTap: onTap,
              customBorder: shape,
              child: ConstrainedBox(
                constraints: const BoxConstraints(
                  minHeight: DealGoDimensions.minTapTarget,
                ),
                child: Align(widthFactor: 1, child: content),
              ),
            ),
    );

    return Semantics(
      label: label,
      button: onTap != null,
      selected: onTap != null ? selected : null,
      enabled: enabled,
      child: painted,
    );
  }

  static ({Color background, Color foreground, Color border}) _colors(
    DealGoChipTone tone, {
    required bool selected,
  }) {
    if (selected) {
      return (
        background: DealGoColors.primary,
        foreground: Colors.white,
        border: DealGoColors.primary,
      );
    }
    return switch (tone) {
      DealGoChipTone.neutral => (
        background: DealGoColors.canvas,
        foreground: DealGoColors.textSecondary,
        border: Colors.transparent,
      ),
      DealGoChipTone.brand => (
        background: DealGoColors.subtlePurple,
        foreground: DealGoColors.primary,
        border: Colors.transparent,
      ),
      DealGoChipTone.success => (
        background: DealGoColors.greenSurface,
        foreground: DealGoColors.brandGreen,
        border: Colors.transparent,
      ),
      DealGoChipTone.warning => (
        background: DealGoColors.amberSurface,
        foreground: DealGoColors.warning,
        border: Colors.transparent,
      ),
      DealGoChipTone.danger => (
        background: DealGoColors.dangerSurface,
        foreground: DealGoColors.danger,
        border: Colors.transparent,
      ),
      DealGoChipTone.promo => (
        background: DealGoColors.subtlePurple,
        foreground: DealGoColors.primary,
        border: Colors.transparent,
      ),
    };
  }
}
