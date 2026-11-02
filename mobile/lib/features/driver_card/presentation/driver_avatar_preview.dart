import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../core/design_system/components/dealgo_network_image.dart';
import '../../../core/design_system/icons/dealgo_icons.dart';
import '../../../core/design_system/tokens/dealgo_tokens.dart';
import '../../../core/motion/dealgo_motion.dart';
import '../../../l10n/app_localizations.dart';

/// Full-screen portrait of a driver's photo. Fades and settles into place;
/// it does not pan or pinch.
Future<void> showDriverAvatarPreview(
  BuildContext context, {
  required String imageUrl,
  required String name,
}) {
  final l10n = AppLocalizations.of(context);
  final reduce = DealGoMotion.prefersReducedMotion(context);
  return showGeneralDialog<void>(
    context: context,
    barrierDismissible: true,
    barrierLabel: l10n.driverAvatarClose,
    barrierColor: const Color(0xE6120B1E),
    transitionDuration: DealGoMotion.durationFor(context, DealGoMotion.medium),
    pageBuilder: (dialogContext, _, _) =>
        _DriverAvatarStage(imageUrl: imageUrl, name: name),
    transitionBuilder: (context, animation, _, child) {
      final curved = CurvedAnimation(
        parent: animation,
        curve: DealGoMotion.standard,
      );
      return FadeTransition(
        opacity: curved,
        child: reduce
            ? child
            : ScaleTransition(
                scale: Tween<double>(begin: 0.86, end: 1).animate(curved),
                child: child,
              ),
      );
    },
  );
}

class _DriverAvatarStage extends StatelessWidget {
  const _DriverAvatarStage({required this.imageUrl, required this.name});

  final String imageUrl;
  final String name;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final size = MediaQuery.sizeOf(context);
    final diameter = math.min(size.shortestSide * 0.78, 360.0);
    Widget mark() => ColoredBox(
      color: DealGoColors.subtlePurple,
      child: Center(
        child: Text(
          name.characters.first.toUpperCase(),
          style: Theme.of(context).textTheme.displaySmall?.copyWith(
            color: DealGoColors.primary,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
    );
    return SafeArea(
      child: Material(
        key: const Key('driver-avatar-preview'),
        type: MaterialType.transparency,
        child: Stack(
          children: [
            Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: DealGoSpacing.s24,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    DecoratedBox(
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 3),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.38),
                            blurRadius: 36,
                            offset: const Offset(0, 18),
                          ),
                        ],
                      ),
                      child: ClipOval(
                        child: SizedBox(
                          key: const Key('driver-avatar-preview-photo'),
                          width: diameter,
                          height: diameter,
                          child: DealGoNetworkImage(
                            imageUrl,
                            width: diameter,
                            height: diameter,
                            placeholder: mark(),
                            fallback: mark(),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: DealGoSpacing.s20),
                    Text(
                      name,
                      key: const Key('driver-avatar-preview-name'),
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            Positioned(
              top: DealGoSpacing.s8,
              right: DealGoSpacing.s8,
              child: IconButton(
                key: const Key('driver-avatar-close'),
                tooltip: l10n.driverAvatarClose,
                onPressed: () => Navigator.of(context).pop(),
                style: IconButton.styleFrom(
                  backgroundColor: Colors.white.withValues(alpha: 0.16),
                  foregroundColor: Colors.white,
                ),
                icon: const Icon(DealGoIcons.close),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
