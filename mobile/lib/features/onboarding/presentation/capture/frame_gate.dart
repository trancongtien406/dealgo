import 'capture_config.dart';

import 'dart:typed_data';

/// One camera frame's luma, read in place (no copy). Android NV21/YUV gives
/// plane 0 as Y (pixelStride 1); iOS BGRA uses the green byte as a luma proxy
/// (pixelStride 4, offset 1).
class LumaFrame {
  const LumaFrame({
    required this.bytes,
    required this.width,
    required this.height,
    required this.rowStride,
    this.pixelStride = 1,
    this.offset = 0,
  });

  final Uint8List bytes;
  final int width;
  final int height;
  final int rowStride;
  final int pixelStride;
  final int offset;

  int at(int x, int y) {
    final cx = x < 0 ? 0 : (x >= width ? width - 1 : x);
    final cy = y < 0 ? 0 : (y >= height ? height - 1 : y);
    final i = cy * rowStride + cx * pixelStride + offset;
    return i < bytes.length ? bytes[i] : 0;
  }
}

/// Short on-screen hint (t53u: compact icon + few words only).
enum CaptureHint {
  none,
  findCard,
  closer,
  moreLight,
  noGlare,
  holdStill,
  captured,
}

/// Card guide in frame pixels.
class CardGuide {
  const CardGuide(this.left, this.top, this.right, this.bottom);
  final double left;
  final double top;
  final double right;
  final double bottom;
  double get width => right - left;
  double get height => bottom - top;

  CardGuide scaled(double f) {
    final cx = (left + right) / 2;
    final cy = (top + bottom) / 2;
    return CardGuide(
      cx - width * f / 2,
      cy - height * f / 2,
      cx + width * f / 2,
      cy + height * f / 2,
    );
  }

  /// The on-screen ID-1 frame (88% of the short display side). Phone sensors are
  /// landscape, so for a portrait UI the card's long edge runs along frame Y.
  static CardGuide forFrame(int width, int height, {double fill = 0.88}) {
    const ratio = 54 / 85.6;
    if (width > height) {
      final long = height * fill;
      final short = long * ratio;
      return CardGuide(
        (width - short) / 2,
        (height - long) / 2,
        (width + short) / 2,
        (height + long) / 2,
      );
    }
    final long = width * fill;
    final short = long * ratio;
    return CardGuide(
      (width - long) / 2,
      (height - short) / 2,
      (width + long) / 2,
      (height + short) / 2,
    );
  }
}

/// Thresholds are first guesses; tune on real devices (OPEN, t53u).
class FrameGateConfig {
  const FrameGateConfig({
    this.minMeanLuma = CaptureConfig.frameMinMeanLuma,
    this.maxGlareRatio = CaptureConfig.frameMaxGlareRatio,
    this.minSharpness = CaptureConfig.frameMinSharpness,
    this.maxMotion = CaptureConfig.frameMaxMotion,
    this.edgeGradient = CaptureConfig.frameEdgeGradient,
    this.edgeCoverage = CaptureConfig.frameEdgeCoverage,
  });

  final double minMeanLuma;
  final double maxGlareRatio;
  final double minSharpness;
  final double maxMotion;
  final int edgeGradient;
  final double edgeCoverage;
}

/// Whether a frame is good enough to auto-shoot, else the one hint to show.
/// Order: light → card fully in frame → glare → sharp → still.
CaptureHint evaluateCardFrame(
  LumaFrame frame, {
  LumaFrame? previous,
  FrameGateConfig config = const FrameGateConfig(),
}) {
  final guide = CardGuide.forFrame(frame.width, frame.height);
  final step = (guide.width < guide.height ? guide.width : guide.height) ~/ 24;
  final s = step < 2 ? 2 : step;
  var sum = 0;
  var bright = 0;
  var n = 0;
  var lapSum = 0.0;
  var lapSq = 0.0;
  var lapN = 0;
  for (var y = guide.top.toInt(); y < guide.bottom; y += s) {
    for (var x = guide.left.toInt(); x < guide.right; x += s) {
      final v = frame.at(x, y);
      sum += v;
      n++;
      if (v >= 250) bright++;
      final lap =
          (4 * v -
                  frame.at(x - 1, y) -
                  frame.at(x + 1, y) -
                  frame.at(x, y - 1) -
                  frame.at(x, y + 1))
              .toDouble();
      lapSum += lap;
      lapSq += lap * lap;
      lapN++;
    }
  }
  if (n == 0) return CaptureHint.findCard;
  if (sum / n < config.minMeanLuma) return CaptureHint.moreLight;
  if (cardSidesFound(frame, guide, config) < 3) {
    return cardSidesFound(frame, guide.scaled(0.7), config) >= 3
        ? CaptureHint.closer
        : CaptureHint.findCard;
  }
  if (bright / n > config.maxGlareRatio) return CaptureHint.noGlare;
  final mean = lapSum / lapN;
  if (lapSq / lapN - mean * mean < config.minSharpness) {
    return CaptureHint.holdStill;
  }
  if (previous != null &&
      frameMotion(frame, previous, guide, s) > config.maxMotion) {
    return CaptureHint.holdStill;
  }
  return CaptureHint.none;
}

/// How many of the guide's 4 sides show a strong edge (card border) within a
/// small band around the line.
int cardSidesFound(LumaFrame f, CardGuide g, FrameGateConfig c) {
  final band = (g.width < g.height ? g.width : g.height) * 0.06;
  const samples = 24;
  bool side(double x0, double y0, double x1, double y1, bool vertical) {
    var hits = 0;
    for (var i = 1; i < samples; i++) {
      final t = i / samples;
      final px = x0 + (x1 - x0) * t;
      final py = y0 + (y1 - y0) * t;
      var best = 0;
      for (var o = -band; o <= band; o += 2) {
        final x = (vertical ? px + o : px).round();
        final y = (vertical ? py : py + o).round();
        final grad = vertical
            ? (f.at(x + 2, y) - f.at(x - 2, y)).abs()
            : (f.at(x, y + 2) - f.at(x, y - 2)).abs();
        if (grad > best) best = grad;
      }
      if (best >= c.edgeGradient) hits++;
    }
    return hits / (samples - 1) >= c.edgeCoverage;
  }

  var found = 0;
  if (side(g.left, g.top, g.right, g.top, false)) found++;
  if (side(g.left, g.bottom, g.right, g.bottom, false)) found++;
  if (side(g.left, g.top, g.left, g.bottom, true)) found++;
  if (side(g.right, g.top, g.right, g.bottom, true)) found++;
  return found;
}

/// Mean absolute luma change between two frames inside the guide.
double frameMotion(LumaFrame a, LumaFrame b, CardGuide g, int step) {
  if (a.width != b.width || a.height != b.height) return 0;
  var diff = 0;
  var n = 0;
  for (var y = g.top.toInt(); y < g.bottom; y += step * 2) {
    for (var x = g.left.toInt(); x < g.right; x += step * 2) {
      diff += (a.at(x, y) - b.at(x, y)).abs();
      n++;
    }
  }
  return n == 0 ? 0 : diff / n;
}
