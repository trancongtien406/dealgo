import 'capture_config.dart';

import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../document_image_source.dart';
import 'capture_quality.dart';
import 'frame_gate.dart';

enum AutoCapturePhase { searching, shooting, done }

class DocumentAutoCaptureState extends Equatable {
  const DocumentAutoCaptureState({
    required this.kinds,
    this.index = 0,
    this.phase = AutoCapturePhase.searching,
    this.hint = CaptureHint.findCard,
    this.stableFrames = 0,
    this.results = const {},
  });

  final List<String> kinds;
  final int index;
  final AutoCapturePhase phase;
  final CaptureHint hint;
  final int stableFrames;
  final Map<String, PickedDocumentImage> results;

  String? get kind => index < kinds.length ? kinds[index] : null;
  bool get done => phase == AutoCapturePhase.done;

  DocumentAutoCaptureState copyWith({
    int? index,
    AutoCapturePhase? phase,
    CaptureHint? hint,
    int? stableFrames,
    Map<String, PickedDocumentImage>? results,
  }) => DocumentAutoCaptureState(
    kinds: kinds,
    index: index ?? this.index,
    phase: phase ?? this.phase,
    hint: hint ?? this.hint,
    stableFrames: stableFrames ?? this.stableFrames,
    results: results ?? this.results,
  );

  @override
  List<Object?> get props => [
    kinds,
    index,
    phase,
    hint,
    stableFrames,
    results.keys.toList(),
  ];
}

/// t53u: no shutter. Preview frames feed [onFrame]; after [stableNeeded]
/// good frames in a row the page shoots; the full-res check decides via
/// [onShot]; then it auto-advances (front → back) until every kind is done.
class DocumentAutoCaptureCubit extends Cubit<DocumentAutoCaptureState> {
  DocumentAutoCaptureCubit(List<String> kinds)
    : super(DocumentAutoCaptureState(kinds: kinds));

  static const stableNeeded = CaptureConfig.cardStableFrames;

  void onFrame(CaptureHint hint) {
    if (state.phase != AutoCapturePhase.searching) return;
    if (hint != CaptureHint.none) {
      emit(state.copyWith(hint: hint, stableFrames: 0));
      return;
    }
    final frames = state.stableFrames + 1;
    emit(
      frames >= stableNeeded
          ? state.copyWith(
              phase: AutoCapturePhase.shooting,
              hint: CaptureHint.holdStill,
              stableFrames: 0,
            )
          : state.copyWith(hint: CaptureHint.holdStill, stableFrames: frames),
    );
  }

  /// Result of the still taken after the gate passed; [image] null = camera error.
  void onShot(CaptureQualityReport? report, PickedDocumentImage? image) {
    final kind = state.kind;
    if (state.phase != AutoCapturePhase.shooting || kind == null) return;
    if (report == null || image == null || !report.ok) {
      emit(
        state.copyWith(
          phase: AutoCapturePhase.searching,
          stableFrames: 0,
          hint: _hintFor(report),
        ),
      );
      return;
    }
    final results = {...state.results, kind: image};
    final next = state.index + 1;
    emit(
      state.copyWith(
        index: next,
        results: results,
        phase: next >= state.kinds.length
            ? AutoCapturePhase.done
            : AutoCapturePhase.searching,
        hint: CaptureHint.captured,
        stableFrames: 0,
      ),
    );
  }

  static CaptureHint _hintFor(CaptureQualityReport? report) {
    final issues = report?.issues ?? const <CaptureIssue>[];
    if (issues.contains(CaptureIssue.dark)) return CaptureHint.moreLight;
    if (issues.contains(CaptureIssue.glare)) return CaptureHint.noGlare;
    if (issues.contains(CaptureIssue.blurry)) return CaptureHint.holdStill;
    return CaptureHint.findCard;
  }
}
