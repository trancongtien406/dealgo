import 'capture_config.dart';

import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// One face-detector frame reduced to what liveness needs; keeps ML Kit out of
/// the cubit so it is unit-testable.
class FaceSample extends Equatable {
  const FaceSample({
    required this.faceCount,
    this.yaw = 0,
    this.leftEyeOpen,
    this.rightEyeOpen,
    this.fit = OvalFit.inside,
  });

  final int faceCount;

  /// Head Euler Y in degrees (ML Kit sign; mirrored front camera handled by
  /// accepting either side per step).
  final double yaw;
  final double? leftEyeOpen;
  final double? rightEyeOpen;

  /// Where the face box sits relative to the on-screen oval (see [ovalFitOf]).
  final OvalFit fit;

  @override
  List<Object?> get props => [faceCount, yaw, leftEyeOpen, rightEyeOpen, fit];
}

enum OvalFit { inside, outside, tooSmall }

/// Face box in 0..1 frame fractions (already rotated upright) vs the oval
/// guide centred on screen. Thresholds are first guesses (OPEN: tune on devices).
OvalFit ovalFitOf({
  required double left,
  required double top,
  required double width,
  required double height,
}) {
  final cx = left + width / 2;
  final cy = top + height / 2;
  if ((cx - 0.5).abs() > 0.15 || (cy - 0.5).abs() > 0.18) {
    return OvalFit.outside;
  }
  if (width < 0.3) return OvalFit.tooSmall;
  if (width > 0.9 || left < 0 || left + width > 1) return OvalFit.outside;
  return OvalFit.inside;
}

enum LivenessStep { center, turnLeft, turnRight, blink, done }

enum LivenessHint { none, noFace, manyFaces, outsideOval, closer, timeout }

class LivenessState extends Equatable {
  const LivenessState({
    this.step = LivenessStep.center,
    this.hint = LivenessHint.none,
    this.stableFrames = 0,
    this.sawEyesOpen = false,
  });

  final LivenessStep step;
  final LivenessHint hint;
  final int stableFrames;
  final bool sawEyesOpen;

  bool get passed => step == LivenessStep.done;

  /// t53u: the clip runs from the moment the face is centred until done.
  bool get recording =>
      step != LivenessStep.center && step != LivenessStep.done;

  /// 0..1 for the progress ring.
  double get progress => step.index / LivenessStep.done.index;

  LivenessState copyWith({
    LivenessStep? step,
    LivenessHint? hint,
    int? stableFrames,
    bool? sawEyesOpen,
  }) => LivenessState(
    step: step ?? this.step,
    hint: hint ?? this.hint,
    stableFrames: stableFrames ?? this.stableFrames,
    sawEyesOpen: sawEyesOpen ?? this.sawEyesOpen,
  );

  @override
  List<Object?> get props => [step, hint, stableFrames, sawEyesOpen];
}

/// Guided active liveness: centre → turn left → turn right → blink (t52u).
///
/// Turn left/right accept either yaw sign by magnitude in sequence (first one
/// side, then the other) so mirrored previews on some devices still pass.
/// This is a device-side signal for ops, not proof: ops still compares faces.
class LivenessCubit extends Cubit<LivenessState> {
  LivenessCubit() : super(const LivenessState());

  static const centerYaw = CaptureConfig.livenessCenterYaw;
  static const turnYaw = CaptureConfig.livenessTurnYaw;
  static const eyesOpen = CaptureConfig.livenessEyesOpen;
  static const eyesClosed = CaptureConfig.livenessEyesClosed;
  static const stableNeeded = CaptureConfig.livenessStableFrames;
  double? _firstTurnSign;

  void onSample(FaceSample sample) {
    if (state.passed) {
      return;
    }
    if (sample.faceCount == 0) {
      emit(state.copyWith(hint: LivenessHint.noFace, stableFrames: 0));
      return;
    }
    if (sample.faceCount > 1) {
      emit(state.copyWith(hint: LivenessHint.manyFaces, stableFrames: 0));
      return;
    }
    final base = state.copyWith(hint: LivenessHint.none);
    switch (state.step) {
      case LivenessStep.center:
        // t53u: recording starts when this step passes (face inside the oval).
        if (sample.fit != OvalFit.inside) {
          emit(
            base.copyWith(
              hint: sample.fit == OvalFit.tooSmall
                  ? LivenessHint.closer
                  : LivenessHint.outsideOval,
              stableFrames: 0,
            ),
          );
          return;
        }
        _advanceWhen(
          base,
          sample.yaw.abs() <= centerYaw,
          LivenessStep.turnLeft,
        );
      case LivenessStep.turnLeft:
        final turned = sample.yaw.abs() >= turnYaw;
        if (turned) {
          _firstTurnSign ??= sample.yaw.sign;
        }
        _advanceWhen(base, turned, LivenessStep.turnRight);
      case LivenessStep.turnRight:
        final other =
            _firstTurnSign != null && sample.yaw.sign == -_firstTurnSign!;
        _advanceWhen(
          base,
          other && sample.yaw.abs() >= turnYaw,
          LivenessStep.blink,
        );
      case LivenessStep.blink:
        final l = sample.leftEyeOpen;
        final r = sample.rightEyeOpen;
        if (l == null || r == null) {
          emit(base);
          return;
        }
        if (l >= eyesOpen && r >= eyesOpen) {
          emit(base.copyWith(sawEyesOpen: true));
        } else if (state.sawEyesOpen && l <= eyesClosed && r <= eyesClosed) {
          emit(base.copyWith(step: LivenessStep.done, stableFrames: 0));
        } else {
          emit(base);
        }
      case LivenessStep.done:
        break;
    }
  }

  void timeout() {
    if (!state.passed) {
      emit(state.copyWith(hint: LivenessHint.timeout));
    }
  }

  void restart() {
    _firstTurnSign = null;
    emit(const LivenessState());
  }

  void _advanceWhen(LivenessState base, bool ok, LivenessStep next) {
    if (!ok) {
      emit(base.copyWith(stableFrames: 0));
      return;
    }
    final frames = state.stableFrames + 1;
    emit(
      frames >= stableNeeded
          ? base.copyWith(step: next, stableFrames: 0)
          : base.copyWith(stableFrames: frames),
    );
  }
}
