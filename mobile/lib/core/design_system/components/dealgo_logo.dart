import 'package:flutter/material.dart';

import '../tokens/dealgo_tokens.dart';

/// Supported layout orientations for the [DealGoLogo].
enum DealGoLogoVariant {
  /// Wordmark only: "Deal" in purple, "Go" in green.
  wordmarkOnly,

  /// Icon mark only: squircle badge with gradient and stylized D/G mark.
  iconOnly,

  /// Horizontal lockup: Icon badge on left, Wordmark and optional subtitle on right.
  horizontal,

  /// Stacked lockup: Large icon badge on top, Wordmark and slogan below.
  stacked,
}

/// Official DealGo Brand Logo Component.
class DealGoLogo extends StatelessWidget {
  const DealGoLogo({
    super.key,
    this.variant = DealGoLogoVariant.horizontal,
    this.size = 36.0,
    this.subtitle,
    this.showSlogan = false,
  });

  const DealGoLogo.wordmark({
    super.key,
    this.size = 24.0,
  })  : variant = DealGoLogoVariant.wordmarkOnly,
        subtitle = null,
        showSlogan = false;

  const DealGoLogo.icon({
    super.key,
    this.size = 40.0,
  })  : variant = DealGoLogoVariant.iconOnly,
        subtitle = null,
        showSlogan = false;

  const DealGoLogo.stacked({
    super.key,
    this.size = 72.0,
    this.showSlogan = true,
    this.subtitle,
  }) : variant = DealGoLogoVariant.stacked;

  final DealGoLogoVariant variant;
  final double size;
  final String? subtitle;
  final bool showSlogan;

  @override
  Widget build(BuildContext context) {
    switch (variant) {
      case DealGoLogoVariant.wordmarkOnly:
        return _buildWordmark(context, fontSize: size);

      case DealGoLogoVariant.iconOnly:
        return _buildIconMark(size: size);

      case DealGoLogoVariant.horizontal:
        return Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            _buildIconMark(size: size),
            SizedBox(width: size * 0.25),
            Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildWordmark(context, fontSize: size * 0.65),
                if (subtitle != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    subtitle!,
                    style: TextStyle(
                      fontSize: size * 0.28,
                      fontWeight: FontWeight.w600,
                      color: DealGoColors.textSecondary,
                      letterSpacing: 0.5,
                    ),
                  ),
                ],
              ],
            ),
          ],
        );

      case DealGoLogoVariant.stacked:
        return Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            _buildIconMark(size: size),
            SizedBox(height: size * 0.2),
            _buildWordmark(context, fontSize: size * 0.45),
            if (showSlogan || subtitle != null) ...[
              const SizedBox(height: 4),
              Text(
                subtitle ?? 'Đi muôn nơi · Ăn vạn món',
                style: TextStyle(
                  fontSize: size * 0.22,
                  fontWeight: FontWeight.w600,
                  color: DealGoColors.textSecondary,
                  letterSpacing: 0.8,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ],
        );
    }
  }

  Widget _buildWordmark(BuildContext context, {required double fontSize}) {
    return Text.rich(
      TextSpan(
        style: TextStyle(
          fontSize: fontSize,
          fontWeight: FontWeight.w900,
          letterSpacing: -0.5,
        ),
        children: const [
          TextSpan(
            text: 'Deal',
            style: TextStyle(color: DealGoColors.primary),
          ),
          TextSpan(
            text: 'Go',
            style: TextStyle(color: DealGoColors.brandGreen),
          ),
        ],
      ),
    );
  }

  Widget _buildIconMark({required double size}) {
    final borderRadius = BorderRadius.circular(size * 0.28);
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        borderRadius: borderRadius,
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFF1E1B4B),
            Color(0xFF2E1065),
            Color(0xFF090A0F),
          ],
        ),
        boxShadow: [
          BoxShadow(
            color: DealGoColors.primary.withValues(alpha: 0.25),
            blurRadius: size * 0.25,
            offset: Offset(0, size * 0.1),
          ),
        ],
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.12),
          width: 1,
        ),
      ),
      child: ClipRRect(
        borderRadius: borderRadius,
        child: Image.asset(
          'assets/images/dealgo_app_icon.png',
          width: size,
          height: size,
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) => CustomPaint(
            size: Size(size, size),
            painter: _DealGoLogoFallbackPainter(),
          ),
        ),
      ),
    );
  }
}

class _DealGoLogoFallbackPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final textPainter = TextPainter(
      text: TextSpan(
        text: 'DG',
        style: TextStyle(
          fontSize: size.width * 0.42,
          fontWeight: FontWeight.w900,
          color: Colors.white,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    textPainter.paint(
      canvas,
      Offset(
        (size.width - textPainter.width) / 2,
        (size.height - textPainter.height) / 2,
      ),
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
