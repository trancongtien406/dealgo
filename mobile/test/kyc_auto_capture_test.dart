import 'package:dealgo/features/onboarding/domain/entities/partner_documents.dart';
import 'package:dealgo/features/onboarding/presentation/capture/capture_hint.dart';
import 'package:dealgo/features/onboarding/presentation/capture/camera_orientation.dart';
import 'package:dealgo/features/onboarding/presentation/capture/capture_quality.dart';
import 'package:dealgo/features/onboarding/presentation/capture/document_auto_capture_cubit.dart';
import 'package:dealgo/features/onboarding/presentation/capture/frame_gate.dart';
import 'package:dealgo/features/onboarding/presentation/capture/face_liveness_page.dart';
import 'package:dealgo/features/onboarding/presentation/capture/liveness_cubit.dart';
import 'package:dealgo/features/onboarding/presentation/capture/smart_capture.dart';
import 'package:dealgo/features/onboarding/presentation/cubit/partner_document_draft.dart';
import 'package:dealgo/features/onboarding/presentation/document_image_source.dart';
import 'package:dealgo/features/onboarding/presentation/widgets/partner_kyc_widgets.dart';
import 'package:dealgo/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:camera/camera.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:provider/provider.dart';

const _w = 640;
const _h = 480;

/// Synthetic landscape sensor frame: background + a textured card.
LumaFrame _frame({
  int background = 60,
  int card = 170,
  double scale = 1,
  double glare = 0,
  bool texture = true,
  int shift = 0,
}) {
  final bytes = Uint8List(_w * _h)..fillRange(0, _w * _h, background);
  final g = CardGuide.forFrame(_w, _h).scaled(scale);
  final glareRows = (g.height * glare).toInt();
  for (var y = g.top.ceil(); y < g.bottom; y++) {
    for (var x = g.left.ceil(); x < g.right; x++) {
      var v = card;
      if (texture && ((x + shift) ~/ 3 + y ~/ 3).isEven) v -= 40;
      if (y - g.top < glareRows) v = 255;
      bytes[y * _w + x] = v;
    }
  }
  return LumaFrame(bytes: bytes, width: _w, height: _h, rowStride: _w);
}

PickedDocumentImage _img([Map<String, bool> checks = const {}]) =>
    PickedDocumentImage(
      bytes: Uint8List.fromList([1, 2, 3]),
      contentType: 'image/jpeg',
      checks: checks,
    );

const _okReport = CaptureQualityReport(
  sharpness: 100,
  glareRatio: 0,
  meanLuma: 120,
  issues: {},
);

void main() {
  group('camera frame orientation', () {
    const front = CameraDescription(
      name: 'front',
      lensDirection: CameraLensDirection.front,
      sensorOrientation: 90,
    );
    const back = CameraDescription(
      name: 'back',
      lensDirection: CameraLensDirection.back,
      sensorOrientation: 90,
    );

    test('uses lens-aware Android compensation', () {
      expect(
        cameraRotationDegrees(
          camera: front,
          deviceOrientation: DeviceOrientation.landscapeLeft,
          isIOS: false,
        ),
        180,
      );
      expect(
        cameraRotationDegrees(
          camera: back,
          deviceOrientation: DeviceOrientation.landscapeLeft,
          isIOS: false,
        ),
        0,
      );
      expect(
        cameraRotationDegrees(
          camera: front,
          deviceOrientation: DeviceOrientation.landscapeRight,
          isIOS: true,
        ),
        90,
      );
    });

    test('bakes JPEG EXIF rotation into portrait pixels before upload', () {
      final source = img.Image(width: 4, height: 2)
        ..exif.imageIfd.orientation = 6;
      final prepared = prepareIdPhoto(
        Uint8List.fromList(img.encodeJpg(source)),
      );
      final uploaded = img.decodeJpg(prepared!.jpeg);

      expect(uploaded, isNotNull);
      expect((uploaded!.width, uploaded.height), (2, 4));
      expect(uploaded.exif.imageIfd.orientation, isNull);
    });
  });

  group('frame gate (t53u auto capture)', () {
    test('card fully in frame, sharp, lit → shoot', () {
      expect(evaluateCardFrame(_frame()), CaptureHint.none);
    });
    test('dark → more light', () {
      expect(
        evaluateCardFrame(_frame(background: 10, card: 40)),
        CaptureHint.moreLight,
      );
    });
    test('no card edges → find card', () {
      expect(
        evaluateCardFrame(_frame(background: 120, card: 120, texture: false)),
        CaptureHint.findCard,
      );
    });
    test('card too small → closer', () {
      expect(evaluateCardFrame(_frame(scale: 0.7)), CaptureHint.closer);
    });
    test('glare → no glare', () {
      expect(evaluateCardFrame(_frame(glare: 0.2)), CaptureHint.noGlare);
    });
    test('moving between frames → hold still', () {
      expect(
        evaluateCardFrame(_frame(shift: 3), previous: _frame()),
        CaptureHint.holdStill,
      );
    });
  });

  group('DocumentAutoCaptureCubit', () {
    test(
      'auto-shoots after stable frames and advances front → back → done',
      () {
        final cubit = DocumentAutoCaptureCubit(const [
          PartnerDocumentKind.idFront,
          PartnerDocumentKind.idBack,
        ]);
        for (var i = 0; i < DocumentAutoCaptureCubit.stableNeeded - 1; i++) {
          cubit.onFrame(CaptureHint.none);
        }
        expect(cubit.state.phase, AutoCapturePhase.searching);
        cubit.onFrame(CaptureHint.none);
        expect(cubit.state.phase, AutoCapturePhase.shooting);
        cubit.onShot(_okReport, _img());
        expect(cubit.state.kind, PartnerDocumentKind.idBack);
        expect(cubit.state.hint, CaptureHint.captured);
        for (var i = 0; i < DocumentAutoCaptureCubit.stableNeeded; i++) {
          cubit.onFrame(CaptureHint.none);
        }
        cubit.onShot(_okReport, _img());
        expect(cubit.state.done, isTrue);
        expect(cubit.state.results.keys, [
          PartnerDocumentKind.idFront,
          PartnerDocumentKind.idBack,
        ]);
      },
    );

    test('a bad frame resets the streak; a bad still goes back to searching with a hint', () {
      final cubit = DocumentAutoCaptureCubit(const [
        PartnerDocumentKind.idFront,
      ]);
      cubit
        ..onFrame(CaptureHint.none)
        ..onFrame(CaptureHint.noGlare);
      expect(cubit.state.stableFrames, 0);
      expect(cubit.state.hint, CaptureHint.noGlare);
      for (var i = 0; i < DocumentAutoCaptureCubit.stableNeeded; i++) {
        cubit.onFrame(CaptureHint.none);
      }
      cubit.onShot(
        const CaptureQualityReport(
          sharpness: 5,
          glareRatio: 0,
          meanLuma: 120,
          issues: {CaptureIssue.blurry},
        ),
        _img(),
      );
      expect(cubit.state.phase, AutoCapturePhase.searching);
      expect(cubit.state.hint, CaptureHint.holdStill);
      expect(cubit.state.results, isEmpty);
    });
  });

  group('LivenessCubit oval + recording', () {
    test('ovalFitOf', () {
      expect(
        ovalFitOf(left: 0.3, top: 0.3, width: 0.4, height: 0.4),
        OvalFit.inside,
      );
      expect(
        ovalFitOf(left: 0.0, top: 0.3, width: 0.4, height: 0.4),
        OvalFit.outside,
      );
      expect(
        ovalFitOf(left: 0.42, top: 0.42, width: 0.16, height: 0.16),
        OvalFit.tooSmall,
      );
    });

    test('recording starts only once the face is inside the oval, then blink/turns finish it', () {
      final cubit = LivenessCubit();
      cubit.onSample(const FaceSample(faceCount: 1, fit: OvalFit.outside));
      expect(cubit.state.hint, LivenessHint.outsideOval);
      cubit.onSample(const FaceSample(faceCount: 1, fit: OvalFit.tooSmall));
      expect(cubit.state.hint, LivenessHint.closer);
      expect(cubit.state.recording, isFalse);
      for (var i = 0; i < LivenessCubit.stableNeeded; i++) {
        cubit.onSample(const FaceSample(faceCount: 1));
      }
      expect(cubit.state.step, LivenessStep.turnLeft);
      expect(cubit.state.recording, isTrue);
      for (var i = 0; i < LivenessCubit.stableNeeded; i++) {
        cubit.onSample(
          const FaceSample(faceCount: 1, yaw: 30, fit: OvalFit.outside),
        );
      }
      for (var i = 0; i < LivenessCubit.stableNeeded; i++) {
        cubit.onSample(const FaceSample(faceCount: 1, yaw: -30));
      }
      expect(cubit.state.step, LivenessStep.blink);
      cubit
        ..onSample(
          const FaceSample(faceCount: 1, leftEyeOpen: 0.9, rightEyeOpen: 0.9),
        )
        ..onSample(
          const FaceSample(faceCount: 1, leftEyeOpen: 0.1, rightEyeOpen: 0.1),
        );
      expect(cubit.state.passed, isTrue);
      expect(cubit.state.recording, isFalse);
    });

    test('same-side turn twice does not pass; two faces is flagged', () {
      final cubit = LivenessCubit();
      for (var i = 0; i < LivenessCubit.stableNeeded; i++) {
        cubit.onSample(const FaceSample(faceCount: 1));
      }
      for (var i = 0; i < LivenessCubit.stableNeeded * 3; i++) {
        cubit.onSample(const FaceSample(faceCount: 1, yaw: 30));
      }
      expect(cubit.state.step, LivenessStep.turnRight);
      cubit.onSample(const FaceSample(faceCount: 2));
      expect(cubit.state.hint, LivenessHint.manyFaces);
      cubit.timeout();
      expect(cubit.state.hint, LivenessHint.timeout);
      cubit.restart();
      expect(cubit.state.step, LivenessStep.center);
    });
  });

  test('draft uploads add the optional face clip after the required kinds', () {
    final draft = const PartnerDocumentDraft()
        .attach(
          PartnerDocumentKind.selfie,
          _img({CaptureMetadataKeys.livenessPassed: true}),
        )
        .attach(PartnerDocumentKind.selfieVideo, _img());
    final kinds = draft
        .uploads(PartnerDocumentKind.driverRequired)
        .map((u) => u.kind)
        .toList();
    expect(kinds, [
      PartnerDocumentKind.selfie,
      PartnerDocumentKind.selfieVideo,
    ]);
    expect(draft.captureMetadata(), {CaptureMetadataKeys.livenessPassed: true});
    expect(
      const PartnerDocumentDraft().uploads(
        PartnerDocumentKind.merchantRequired,
      ),
      isEmpty,
    );
  });

  group('widgets', () {
    Widget app(Widget child) => MaterialApp(
      locale: const Locale('vi'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(body: SingleChildScrollView(child: child)),
    );

    testWidgets('hint chip shows short Vietnamese hints', (tester) async {
      await tester.pumpWidget(
        app(const CaptureHintChip(hint: CaptureHint.closer)),
      );
      expect(find.text('Lại gần hơn'), findsOneWidget);
      await tester.pumpWidget(
        app(const CaptureHintChip(hint: CaptureHint.moreLight)),
      );
      expect(find.text('Thêm ánh sáng'), findsOneWidget);
      await tester.pumpWidget(
        app(const CaptureHintChip(hint: CaptureHint.holdStill)),
      );
      expect(find.text('Giữ yên'), findsOneWidget);
    });

    testWidgets('liveness prompt shows recording badge and oval hint', (
      tester,
    ) async {
      await tester.pumpWidget(
        app(
          LivenessPrompt(
            state: const LivenessState(step: LivenessStep.blink),
            onRetry: () {},
          ),
        ),
      );
      expect(find.byKey(const Key('liveness-recording')), findsOneWidget);
      expect(find.text('Chớp mắt'), findsOneWidget);
      await tester.pumpWidget(
        app(
          LivenessPrompt(
            state: const LivenessState(hint: LivenessHint.outsideOval),
            onRetry: () {},
          ),
        ),
      );
      expect(find.byKey(const Key('liveness-recording')), findsNothing);
      expect(find.text('Đưa mặt vào khung'), findsOneWidget);
    });

    testWidgets(
      'slot: one auto capture fills front and back; no shutter button exists',
      (tester) async {
        final picked = <String>[];
        await tester.pumpWidget(
          Provider<SmartCaptureLauncher>.value(
            value: _FakeLauncher(),
            child: app(
              PartnerDocumentSlot(
                kind: PartnerDocumentKind.idFront,
                draft: const PartnerDocumentDraft(),
                source: _NoSource(),
                onPicked: (_) => picked.add(PartnerDocumentKind.idFront),
                onPickedOther: (kind, _) => picked.add(kind),
                onRemove: () {},
              ),
            ),
          ),
        );
        await tester.tap(
          find.byKey(const Key('doc-camera-${PartnerDocumentKind.idFront}')),
        );
        await tester.pumpAndSettle();
        expect(picked, [
          PartnerDocumentKind.idFront,
          PartnerDocumentKind.idBack,
        ]);
        expect(find.byKey(const Key('capture-shoot')), findsNothing);
      },
    );
  });
}

class _FakeLauncher implements SmartCaptureLauncher {
  @override
  bool supports(String kind) => true;

  @override
  Future<Map<String, PickedDocumentImage>?> capture(
    BuildContext context, {
    required String kind,
  }) async => {for (final k in smartCaptureSequence(kind)) k: _img()};
}

class _NoSource implements DocumentImageSource {
  @override
  Future<PickedDocumentImage?> pick({
    required bool camera,
    bool front = false,
  }) async => null;
}
