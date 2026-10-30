import 'package:flutter/material.dart';

import '../../../../core/design_system/icons/dealgo_icons.dart';
import '../../../../core/design_system/tokens/dealgo_tokens.dart';
import '../../../../l10n/app_localizations.dart';
import 'frame_gate.dart';

/// t53u: one compact icon + a two/three-word hint over the camera.
class CaptureHintChip extends StatelessWidget {
  const CaptureHintChip({required this.hint, super.key});

  final CaptureHint hint;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final (icon, text, color) = switch (hint) {
      CaptureHint.none => (
        DealGoIcons.scan,
        l10n.kycHintHoldStill,
        Colors.white,
      ),
      CaptureHint.findCard => (
        DealGoIcons.idCard,
        l10n.kycHintFindCard,
        Colors.white,
      ),
      CaptureHint.closer => (
        DealGoIcons.scan,
        l10n.kycHintCloser,
        DealGoColors.amber,
      ),
      CaptureHint.moreLight => (
        DealGoIcons.bolt,
        l10n.kycHintMoreLight,
        DealGoColors.amber,
      ),
      CaptureHint.noGlare => (
        DealGoIcons.warning,
        l10n.kycHintNoGlare,
        DealGoColors.amber,
      ),
      CaptureHint.holdStill => (
        DealGoIcons.pause,
        l10n.kycHintHoldStill,
        Colors.white,
      ),
      CaptureHint.captured => (
        DealGoIcons.success,
        l10n.kycHintCaptured,
        DealGoColors.brandGreen,
      ),
    };
    return HintPill(
      key: Key('capture-hint-${hint.name}'),
      icon: icon,
      text: text,
      color: color,
    );
  }
}

class HintPill extends StatelessWidget {
  const HintPill({
    required this.icon,
    required this.text,
    required this.color,
    super.key,
  });

  final IconData icon;
  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.black54,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: DealGoSpacing.s12,
          vertical: DealGoSpacing.s8,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: color, size: 18),
            const SizedBox(width: DealGoSpacing.s8),
            Text(
              text,
              style: TextStyle(color: color, fontWeight: FontWeight.w600),
            ),
          ],
        ),
      ),
    );
  }
}
