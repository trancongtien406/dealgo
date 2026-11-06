import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../icons/dealgo_icons.dart';
import '../tokens/dealgo_tokens.dart';
import 'dealgo_image_cache.dart';
import 'dealgo_skeleton.dart';

/// Shimmering placeholder shown while a network image is loading.
class DealGoImagePlaceholder extends StatelessWidget {
  const DealGoImagePlaceholder({
    this.width,
    this.height,
    super.key,
  });

  final double? width;
  final double? height;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final w = width ?? constraints.maxWidth;
        final h = height ?? constraints.maxHeight;
        final minSide = math.min(
          w.isFinite ? w : 64.0,
          h.isFinite ? h : 64.0,
        );
        final showIcon = minSide >= 44;
        final iconSize = (minSide * 0.28).clamp(16.0, 28.0);
        return DealGoShimmer(
          animateInTests: false,
          child: DecoratedBox(
            decoration: BoxDecoration(color: DealGoColors.skeletonBase),
            child: showIcon
                ? Center(
                    child: Icon(
                      DealGoIcons.image,
                      size: iconSize,
                      color: DealGoColors.textTertiary.withValues(alpha: 0.45),
                    ),
                  )
                : const SizedBox.expand(),
          ),
        );
      },
    );
  }
}

/// Distinct visual fallback when a network image fails to load (404 / offline).
class DealGoImageFallback extends StatelessWidget {
  const DealGoImageFallback({
    this.width,
    this.height,
    super.key,
  });

  final double? width;
  final double? height;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final w = width ?? constraints.maxWidth;
        final h = height ?? constraints.maxHeight;
        final minSide = math.min(
          w.isFinite ? w : 64.0,
          h.isFinite ? h : 64.0,
        );
        final showBadge = minSide >= 36;
        final iconSize = (minSide * 0.26).clamp(14.0, 24.0);
        return DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                DealGoColors.skeletonBase,
                DealGoColors.lavender,
              ],
            ),
          ),
          child: showBadge
              ? Center(
                  child: Container(
                    padding: EdgeInsets.all(minSide >= 64 ? 8 : 5),
                    decoration: BoxDecoration(
                      color: DealGoColors.card.withValues(alpha: 0.72),
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: DealGoColors.border.withValues(alpha: 0.8),
                      ),
                    ),
                    child: Icon(
                      DealGoIcons.image,
                      size: iconSize,
                      color: DealGoColors.textTertiary,
                    ),
                  ),
                )
              : const SizedBox.expand(),
        );
      },
    );
  }
}

/// Network photo that never stretches: always [BoxFit.cover] by default,
/// shows [placeholder] (or [DealGoImagePlaceholder]) while loading, [fallback]
/// (or [DealGoImageFallback]) on error, and decodes at display size instead of
/// the full upload.
///
/// The caller owns the frame (SizedBox / AspectRatio / ClipRRect); this widget
/// only fills it.
class DealGoNetworkImage extends StatelessWidget {
  const DealGoNetworkImage(
    this.url, {
    this.width,
    this.height,
    this.fit = BoxFit.cover,
    this.alignment = Alignment.center,
    this.fallback,
    this.placeholder,
    this.filterQuality = FilterQuality.medium,
    this.gaplessPlayback = false,
    this.onError,
    super.key,
  });

  final String url;
  final double? width;
  final double? height;
  final BoxFit fit;
  final Alignment alignment;

  /// Optional callback invoked when the image fails to load.
  final void Function(Object error, StackTrace? stack)? onError;

  /// Shown when the image fails to load. Defaults to [DealGoImageFallback].
  final Widget? fallback;

  /// Shown until the first frame arrives. Defaults to [DealGoImagePlaceholder].
  final Widget? placeholder;
  final FilterQuality filterQuality;
  final bool gaplessPlayback;

  /// Upper bound for the decoded width, in physical pixels.
  static const int maxDecodeWidth = 2048;

  /// Decoded width for a box of [boxWidth] x [boxHeight] logical pixels.
  ///
  /// `cover` scales by whichever side is tighter, so a square box showing a
  /// 2:1 landscape photo needs twice its own width to stay sharp. Decoding at
  /// `max(w, 2h)` covers photos up to 2:1 without upscaling; only the width is
  /// set, so the aspect ratio of the decoded image is preserved.
  static int decodeWidth(double boxWidth, double? boxHeight, double dpr) {
    final h = boxHeight != null && boxHeight.isFinite ? boxHeight : 0.0;
    final logical = math.max(boxWidth, h * 2);
    return (logical * dpr).round().clamp(1, maxDecodeWidth);
  }

  @override
  Widget build(BuildContext context) {
    final dpr = MediaQuery.maybeDevicePixelRatioOf(context) ?? 2.0;
    final screenWidth = MediaQuery.maybeSizeOf(context)?.width ?? 400;
    return LayoutBuilder(
      builder: (context, constraints) {
        final w = width != null && width!.isFinite
            ? width!
            : constraints.hasBoundedWidth
            ? constraints.maxWidth
            : screenWidth;
        final h = height != null && height!.isFinite
            ? height
            : constraints.hasBoundedHeight
            ? constraints.maxHeight
            : null;
        return Image(
          image: DealGoImageCache.provider(
            url,
            decodeWidth: decodeWidth(w, h, dpr),
          ),
          width: width,
          height: height,
          fit: fit,
          alignment: alignment,
          filterQuality: filterQuality,
          gaplessPlayback: gaplessPlayback,
          frameBuilder: (context, child, frame, sync) {
            if (sync || frame != null) return child;
            return SizedBox(
              width: width,
              height: height,
              child:
                  placeholder ??
                  DealGoImagePlaceholder(width: width, height: height),
            );
          },
          errorBuilder: (context, error, stack) {
            onError?.call(error, stack);
            return SizedBox(
              width: width,
              height: height,
              child:
                  fallback ?? DealGoImageFallback(width: width, height: height),
            );
          },
        );
      },
    );
  }
}
