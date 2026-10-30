import 'capture_config.dart';

import 'dart:math' as math;
import 'dart:typed_data';

import 'package:image/image.dart' as img;

/// Why an ID photo looks unusable. Advisory: the applicant may still keep it,
/// and ops reviews every photo by hand (t52u).
enum CaptureIssue { blurry, glare, dark }

class CaptureQualityReport {
  const CaptureQualityReport({
    required this.sharpness,
    required this.glareRatio,
    required this.meanLuma,
    required this.issues,
  });

  /// Variance of the Laplacian on a 320px grey copy; low = blurry.
  final double sharpness;

  /// Share of near-white pixels; high = flash/lamp reflection.
  final double glareRatio;

  /// 0..255 average brightness.
  final double meanLuma;
  final Set<CaptureIssue> issues;

  bool get ok => issues.isEmpty;
}

/// Thresholds are first guesses tuned on a laptop webcam; tune on real phones
/// before relying on them (OPEN in t52u decisions).
class CaptureQualityThresholds {
  const CaptureQualityThresholds({
    this.minSharpness = CaptureConfig.photoMinSharpness,
    this.maxGlareRatio = CaptureConfig.photoMaxGlareRatio,
    this.minMeanLuma = CaptureConfig.photoMinMeanLuma,
  });

  final double minSharpness;
  final double maxGlareRatio;
  final double minMeanLuma;
}

/// Pure-Dart blur/glare/darkness check; runs off the UI isolate via `compute`.
CaptureQualityReport checkCaptureQuality(
  img.Image source, {
  CaptureQualityThresholds thresholds = const CaptureQualityThresholds(),
}) {
  final small = source.width > 320
      ? img.copyResize(source, width: 320)
      : source;
  final w = small.width;
  final h = small.height;
  final luma = Float64List(w * h);
  var sum = 0.0;
  var bright = 0;
  for (var y = 0; y < h; y++) {
    for (var x = 0; x < w; x++) {
      final p = small.getPixel(x, y);
      final l = 0.299 * p.r + 0.587 * p.g + 0.114 * p.b;
      luma[y * w + x] = l.toDouble();
      sum += l;
      if (l >= 250) {
        bright++;
      }
    }
  }
  final count = math.max(1, w * h);
  final mean = sum / count;
  var lapSum = 0.0;
  var lapSq = 0.0;
  var n = 0;
  for (var y = 1; y < h - 1; y++) {
    for (var x = 1; x < w - 1; x++) {
      final i = y * w + x;
      final v =
          luma[i - w] + luma[i + w] + luma[i - 1] + luma[i + 1] - 4 * luma[i];
      lapSum += v;
      lapSq += v * v;
      n++;
    }
  }
  final lapMean = n == 0 ? 0.0 : lapSum / n;
  final sharpness = n == 0 ? 0.0 : lapSq / n - lapMean * lapMean;
  final glare = bright / count;
  return CaptureQualityReport(
    sharpness: sharpness,
    glareRatio: glare,
    meanLuma: mean,
    issues: {
      if (sharpness < thresholds.minSharpness) CaptureIssue.blurry,
      if (glare > thresholds.maxGlareRatio) CaptureIssue.glare,
      if (mean < thresholds.minMeanLuma) CaptureIssue.dark,
    },
  );
}

/// Decode + downscale to the upload size (1600px, q80) + quality check.
/// Top-level so it can run in `compute`.
({Uint8List jpeg, CaptureQualityReport report})? prepareIdPhoto(
  Uint8List bytes,
) {
  final decoded = img.decodeImage(bytes);
  if (decoded == null) {
    return null;
  }
  final oriented = img.bakeOrientation(decoded);
  final longest = math.max(oriented.width, oriented.height);
  final resized = longest > 1600
      ? img.copyResize(
          oriented,
          width: oriented.width >= oriented.height ? 1600 : null,
          height: oriented.height > oriented.width ? 1600 : null,
        )
      : oriented;
  return (
    jpeg: Uint8List.fromList(img.encodeJpg(resized, quality: 80)),
    report: checkCaptureQuality(resized),
  );
}
