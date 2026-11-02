import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../tokens/dealgo_tokens.dart';

/// Network photo that never stretches: always [BoxFit.cover] by default,
/// shows [placeholder] (or a flat skeleton) while loading, [fallback] on
/// error, and decodes at display size instead of the full upload.
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
    super.key,
  });

  final String url;
  final double? width;
  final double? height;
  final BoxFit fit;
  final Alignment alignment;

  /// Shown when the image fails to load. Defaults to a flat skeleton box.
  final Widget? fallback;

  /// Shown until the first frame arrives. Defaults to a flat skeleton box.
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
    final skeleton = ColoredBox(color: DealGoColors.skeletonBase);
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
        return Image.network(
          url,
          width: width,
          height: height,
          fit: fit,
          alignment: alignment,
          filterQuality: filterQuality,
          gaplessPlayback: gaplessPlayback,
          cacheWidth: decodeWidth(w, h, dpr),
          frameBuilder: (context, child, frame, sync) {
            if (sync || frame != null) return child;
            return SizedBox(
              width: width,
              height: height,
              child: placeholder ?? skeleton,
            );
          },
          errorBuilder: (context, error, stack) => SizedBox(
            width: width,
            height: height,
            child: fallback ?? skeleton,
          ),
        );
      },
    );
  }
}
