import 'package:flutter/material.dart';

import '../tokens/dealgo_tokens.dart';
import 'dealgo_illustration.dart';
import 'dealgo_primary_button.dart';

enum DealGoBannerTone { info, warning, offline, empty }

/// Inline status / empty / offline banner. Not a toast replacement for form errors.
class DealGoBanner extends StatelessWidget {
  const DealGoBanner({
    required this.message,
    this.tone = DealGoBannerTone.info,
    this.title,
    this.illustrationAsset,
    this.actionLabel,
    this.onAction,
    super.key,
  });

  final String message;
  final DealGoBannerTone tone;
  final String? title;
  final String? illustrationAsset;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final colors = _toneColors(tone);
    final asset = illustrationAsset;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: colors.background,
        borderRadius: BorderRadius.circular(DealGoRadius.card),
        border: Border.all(color: colors.border),
      ),
      child: Padding(
        padding: const EdgeInsets.all(DealGoSpacing.s16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (asset != null) ...[
              Center(
                child: DealGoIllustration(asset, width: 96, height: 96),
              ),
              const SizedBox(height: DealGoSpacing.s12),
            ],
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(colors.icon, color: colors.foreground, size: 20),
                const SizedBox(width: DealGoSpacing.s8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (title != null)
                        Text(
                          title!,
                          style: textTheme.titleSmall?.copyWith(
                            color: colors.foreground,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      if (title != null) const SizedBox(height: DealGoSpacing.s4),
                      Text(
                        message,
                        style: textTheme.bodyMedium?.copyWith(
                          color: colors.foreground,
                          height: 1.35,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            if (actionLabel != null && onAction != null) ...[
              const SizedBox(height: DealGoSpacing.s12),
              DealGoPrimaryButton(label: actionLabel!, onPressed: onAction!),
            ],
          ],
        ),
      ),
    );
  }

  static ({
    Color background,
    Color foreground,
    Color border,
    IconData icon,
  })
  _toneColors(DealGoBannerTone tone) {
    return switch (tone) {
      DealGoBannerTone.info => (
        background: DealGoColors.greenSurface,
        foreground: DealGoColors.brandGreen,
        border: DealGoColors.brandGreen.withValues(alpha: 0.2),
        icon: Icons.info_outline,
      ),
      DealGoBannerTone.warning => (
        background: DealGoColors.amberSurface,
        foreground: DealGoColors.warning,
        border: DealGoColors.warning.withValues(alpha: 0.2),
        icon: Icons.warning_amber_outlined,
      ),
      DealGoBannerTone.offline => (
        background: DealGoColors.dangerSurface,
        foreground: DealGoColors.danger,
        border: DealGoColors.danger.withValues(alpha: 0.2),
        icon: Icons.wifi_off_outlined,
      ),
      DealGoBannerTone.empty => (
        background: DealGoColors.canvas,
        foreground: DealGoColors.textSecondary,
        border: DealGoColors.border,
        icon: Icons.inbox_outlined,
      ),
    };
  }
}
