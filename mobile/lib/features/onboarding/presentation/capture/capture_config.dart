/// t54u/t56u: every on-device capture threshold in one place. Capture AI is
/// assistance only (auto-shoot when framed, sharp, lit, glare-free + guided
/// liveness clip); there is no OCR, face match or AI verdict — staff review
/// is fully manual. Values are first guesses; tune on real phones (OPEN).
abstract final class CaptureConfig {
  // Still photo quality (capture_quality.dart, after the shot).
  static const double photoMinSharpness = 60;
  static const double photoMaxGlareRatio = 0.08;
  static const double photoMinMeanLuma = 55;

  // Live card framing gate (frame_gate.dart, per preview frame).
  static const double frameMinMeanLuma = 55;
  static const double frameMaxGlareRatio = 0.08;
  static const double frameMinSharpness = 40;
  static const double frameMaxMotion = 12;
  static const int frameEdgeGradient = 24;
  static const double frameEdgeCoverage = 0.5;

  /// Consecutive good frames before the card auto-shoots.
  static const int cardStableFrames = 4;
  static const Duration cardFrameInterval = Duration(milliseconds: 150);

  // Guided liveness (liveness_cubit.dart), ML Kit face angles/probabilities.
  static const double livenessCenterYaw = 10;
  static const double livenessTurnYaw = 25;
  static const double livenessEyesOpen = 0.7;
  static const double livenessEyesClosed = 0.25;
  static const int livenessStableFrames = 3;
  static const Duration livenessTimeout = Duration(seconds: 45);

  /// Liveness clip: required for drivers; kept short at a low preset so it
  /// fits the backend PARTNER_VIDEO_MAX_KB (5120 KB). Oversized → retry.
  static const Duration livenessMaxClip = Duration(seconds: 15);
  static const int livenessMaxClipBytes = 5120 * 1024;
}
