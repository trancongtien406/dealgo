import 'capture_config.dart';

import 'dart:async';
import 'dart:io';

import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';

import '../../../../core/design_system/icons/dealgo_icons.dart';
import '../../../../core/design_system/tokens/dealgo_tokens.dart';
import '../../../../l10n/app_localizations.dart';
import '../../domain/entities/partner_documents.dart';
import '../document_image_source.dart';
import 'camera_cover_preview.dart';
import 'camera_orientation.dart';
import 'capture_hint.dart';
import 'capture_quality.dart';
import 'liveness_cubit.dart';
import 'smart_capture.dart';

/// t53u: front camera, no shutter. ML Kit watches the preview; once the face
/// sits inside the oval it takes the SELFIE still and starts a short clip,
/// guides blink / head turns, then stops on its own. Pops
/// `{SELFIE: still, SELFIE_VIDEO: clip}` (the clip is required; a missing or oversized clip restarts the check).
class FaceLivenessPage extends StatelessWidget {
  const FaceLivenessPage({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => LivenessCubit(),
      child: const _FaceLivenessView(),
    );
  }
}

class _FaceLivenessView extends StatefulWidget {
  const _FaceLivenessView();

  @override
  State<_FaceLivenessView> createState() => _FaceLivenessViewState();
}

class _FaceLivenessViewState extends State<_FaceLivenessView>
    with WidgetsBindingObserver {
  static const _timeout = CaptureConfig.livenessTimeout;
  static const _maxClip = CaptureConfig.livenessMaxClip;

  /// Matches the backend PARTNER_VIDEO_MAX_KB (5120 KB); larger clips retry.
  static const _maxClipBytes = CaptureConfig.livenessMaxClipBytes;
  CameraController? _controller;
  CameraDescription? _camera;
  final _detector = FaceDetector(
    options: FaceDetectorOptions(
      enableClassification: true,
      performanceMode: FaceDetectorMode.fast,
    ),
  );
  bool _processing = false;
  bool _failed = false;
  bool _cameraActive = true;
  int _cameraGeneration = 0;
  bool _busy = false;
  PickedDocumentImage? _still;
  Timer? _timer;
  Timer? _clipTimer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _enterCapture();
  }

  Future<void> _enterCapture() async {
    await SystemChrome.setPreferredOrientations(const [
      DeviceOrientation.portraitUp,
    ]);
    if (mounted) await _open();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _cameraActive = true;
      if (_controller == null) {
        context.read<LivenessCubit>().restart();
        _still = null;
        unawaited(_open());
      }
      return;
    }
    if (state == AppLifecycleState.inactive ||
        state == AppLifecycleState.paused ||
        state == AppLifecycleState.detached) {
      _cameraActive = false;
      _cameraGeneration++;
      _timer?.cancel();
      _clipTimer?.cancel();
      final controller = _controller;
      _controller = null;
      _camera = null;
      if (mounted) setState(() {});
      if (controller != null) unawaited(controller.dispose());
    }
  }

  Future<void> _open() async {
    final generation = _cameraGeneration;
    try {
      final cameras = await availableCameras();
      final front = cameras.firstWhere(
        (c) => c.lensDirection == CameraLensDirection.front,
        orElse: () => cameras.first,
      );
      final controller = CameraController(
        front,
        // t54u: low preset keeps the required clip under 5 MB.
        ResolutionPreset.low,
        enableAudio: false,
        imageFormatGroup: Platform.isAndroid
            ? ImageFormatGroup.nv21
            : ImageFormatGroup.bgra8888,
      );
      await controller.initialize();
      await controller.lockCaptureOrientation(DeviceOrientation.portraitUp);
      if (!mounted || !_cameraActive || generation != _cameraGeneration) {
        await controller.dispose();
        return;
      }
      _failed = false;
      _camera = front;
      setState(() => _controller = controller);
      await controller.startImageStream(_onFrame);
      _armTimer();
    } catch (_) {
      if (mounted && _cameraActive && generation == _cameraGeneration) {
        setState(() => _failed = true);
      }
    }
  }

  void _armTimer() {
    _timer?.cancel();
    _timer = Timer(_timeout, () async {
      if (!mounted) return;
      context.read<LivenessCubit>().timeout();
      await _abortClip();
    });
  }

  Future<void> _onFrame(CameraImage image) async {
    if (_processing || _busy || !mounted) return;
    final input = _toInputImage(image);
    if (input == null) return;
    _processing = true;
    try {
      final faces = await _detector.processImage(input);
      if (!mounted) return;
      final face = faces.length == 1 ? faces.first : null;
      final rotation = _frameRotation();
      if (rotation == null) return;
      final upright = uprightFrameSize(image, rotation);
      final size = Size(upright.width, upright.height);
      final box = face?.boundingBox;
      // Only the cover-cropped part of the frame is visible in the oval.
      final crop = coverCrop(size, _ovalAspect);
      context.read<LivenessCubit>().onSample(
        FaceSample(
          faceCount: faces.length,
          yaw: face?.headEulerAngleY ?? 0,
          leftEyeOpen: face?.leftEyeOpenProbability,
          rightEyeOpen: face?.rightEyeOpenProbability,
          fit: box == null
              ? OvalFit.outside
              : ovalFitOf(
                  left: (box.left / size.width - crop.left) / crop.width,
                  top: (box.top / size.height - crop.top) / crop.height,
                  width: box.width / size.width / crop.width,
                  height: box.height / size.height / crop.height,
                ),
        ),
      );
    } catch (_) {
      // A dropped frame is fine; the next one retries.
    } finally {
      _processing = false;
    }
  }

  static const double _ovalAspect = 3 / 4;

  InputImageRotation? _frameRotation() {
    final camera = _camera;
    final controller = _controller;
    if (camera == null || controller == null) return null;
    return inputImageRotation(
      camera: camera,
      deviceOrientation: controller.value.deviceOrientation,
    );
  }

  InputImage? _toInputImage(CameraImage image) {
    final camera = _camera;
    if (camera == null || image.planes.isEmpty) return null;
    final rotation = _frameRotation();
    final format = InputImageFormatValue.fromRawValue(image.format.raw as int);
    if (rotation == null || format == null) return null;
    if (Platform.isAndroid && format != InputImageFormat.nv21) return null;
    if (Platform.isIOS && format != InputImageFormat.bgra8888) return null;
    final plane = image.planes.first;
    return InputImage.fromBytes(
      bytes: plane.bytes,
      metadata: InputImageMetadata(
        size: Size(image.width.toDouble(), image.height.toDouble()),
        rotation: rotation,
        format: format,
        bytesPerRow: plane.bytesPerRow,
      ),
    );
  }

  /// Face centred: take the SELFIE still, then record while liveness runs.
  Future<void> _beginClip() async {
    final controller = _controller;
    if (controller == null || _busy) return;
    _busy = true;
    try {
      if (controller.value.isStreamingImages) {
        await controller.stopImageStream();
      }
      final file = await controller.takePicture();
      final prepared = await compute(prepareIdPhoto, await file.readAsBytes());
      if (prepared != null) {
        _still = PickedDocumentImage(
          bytes: prepared.jpeg,
          contentType: 'image/jpeg',
          checks: const {CaptureMetadataKeys.faceDetected: true},
        );
      }
      await controller.startVideoRecording(onAvailable: _onFrame);
      _clipTimer?.cancel();
      _clipTimer = Timer(_maxClip, () async {
        if (!mounted || context.read<LivenessCubit>().state.passed) return;
        context.read<LivenessCubit>().timeout();
        await _abortClip();
      });
    } catch (_) {
      if (mounted) setState(() => _failed = true);
    } finally {
      _busy = false;
    }
  }

  Future<void> _abortClip() async {
    _clipTimer?.cancel();
    final controller = _controller;
    if (controller == null) return;
    try {
      if (controller.value.isRecordingVideo) {
        await controller.stopVideoRecording();
      }
    } catch (_) {}
  }

  Future<void> _finish() async {
    final controller = _controller;
    if (controller == null || _busy) return;
    _busy = true;
    _timer?.cancel();
    _clipTimer?.cancel();
    try {
      final clip = controller.value.isRecordingVideo
          ? await controller.stopVideoRecording()
          : null;
      final clipBytes = clip == null ? null : await clip.readAsBytes();
      final still = _still;
      if (!mounted || still == null) return;
      final hasClip =
          clipBytes != null &&
          clipBytes.isNotEmpty &&
          clipBytes.length <= _maxClipBytes;
      if (!hasClip) {
        // t54u: the clip is mandatory — never hand back a selfie without it.
        ScaffoldMessenger.maybeOf(context)?.showSnackBar(
          SnackBar(
            content: Text(AppLocalizations.of(context).livenessClipRetry),
          ),
        );
        _busy = false;
        await _restart();
        return;
      }
      final results = <String, PickedDocumentImage>{
        PartnerDocumentKind.selfie: PickedDocumentImage(
          bytes: still.bytes,
          contentType: still.contentType,
          checks: {
            CaptureMetadataKeys.faceDetected: true,
            CaptureMetadataKeys.livenessPassed: true,
            CaptureMetadataKeys.livenessVideo: true,
          },
        ),
        PartnerDocumentKind.selfieVideo: PickedDocumentImage(
          bytes: clipBytes,
          contentType: clip!.path.toLowerCase().endsWith('.mov')
              ? 'video/quicktime'
              : 'video/mp4',
        ),
      };
      Navigator.of(context).pop(results);
    } catch (_) {
      if (mounted) setState(() => _failed = true);
    } finally {
      _busy = false;
    }
  }

  Future<void> _restart() async {
    await _abortClip();
    if (!mounted) return;
    _still = null;
    context.read<LivenessCubit>().restart();
    final controller = _controller;
    if (controller != null && !controller.value.isStreamingImages) {
      await controller.startImageStream(_onFrame);
    }
    _armTimer();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _cameraActive = false;
    _cameraGeneration++;
    _timer?.cancel();
    _clipTimer?.cancel();
    _controller?.dispose();
    _detector.close();
    SystemChrome.setPreferredOrientations(const [
      DeviceOrientation.portraitUp,
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final controller = _controller;
    return BlocConsumer<LivenessCubit, LivenessState>(
      listenWhen: (a, b) => a.step != b.step,
      listener: (_, state) {
        if (state.passed) {
          _finish();
        } else if (state.step == LivenessStep.turnLeft) {
          _beginClip();
        }
      },
      builder: (context, state) {
        return Scaffold(
          backgroundColor: Colors.black,
          appBar: captureAppBar(l10n.kycLivenessTitle),
          body: SafeArea(
            child: _failed
                ? Center(
                    child: Text(
                      l10n.kycCaptureCameraError,
                      style: const TextStyle(color: Colors.white),
                    ),
                  )
                : Column(
                    children: [
                      Expanded(
                        child: Center(
                          child: AspectRatio(
                            key: const Key('liveness-oval'),
                            aspectRatio: _ovalAspect,
                            child: DecoratedBox(
                              position: DecorationPosition.foreground,
                              decoration: ShapeDecoration(
                                shape: OvalBorder(
                                  side: BorderSide(
                                    color: state.recording
                                        ? DealGoColors.brandGreen
                                        : Colors.white70,
                                    width: 4,
                                  ),
                                ),
                              ),
                              child: ClipOval(
                                child:
                                    controller != null &&
                                        controller.value.isInitialized
                                    ? CameraCoverPreview(
                                        previewSize: portraitPreviewSize(
                                          controller.value.previewSize ??
                                              const Size(640, 480),
                                        ),
                                        child: CameraPreview(controller),
                                      )
                                    : const ColoredBox(color: Colors.black12),
                              ),
                            ),
                          ),
                        ),
                      ),
                      LivenessPrompt(state: state, onRetry: _restart),
                    ],
                  ),
          ),
        );
      },
    );
  }
}

/// Step text, hint and progress; split out so widget tests can pump it alone.
class LivenessPrompt extends StatelessWidget {
  const LivenessPrompt({required this.state, required this.onRetry, super.key});

  final LivenessState state;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final step = switch (state.step) {
      LivenessStep.center => l10n.kycLivenessCenter,
      LivenessStep.turnLeft => l10n.kycLivenessTurnLeft,
      LivenessStep.turnRight => l10n.kycLivenessTurnRight,
      LivenessStep.blink => l10n.kycLivenessBlink,
      LivenessStep.done => l10n.kycLivenessDone,
    };
    final hint = switch (state.hint) {
      LivenessHint.noFace => l10n.kycLivenessNoFace,
      LivenessHint.manyFaces => l10n.kycLivenessManyFaces,
      LivenessHint.outsideOval => l10n.kycHintFaceInOval,
      LivenessHint.closer => l10n.kycHintCloser,
      LivenessHint.timeout => l10n.kycLivenessTimeout,
      LivenessHint.none => null,
    };
    return Padding(
      padding: const EdgeInsets.all(DealGoSpacing.s16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          LinearProgressIndicator(
            value: state.progress,
            color: DealGoColors.brandGreen,
          ),
          const SizedBox(height: DealGoSpacing.s12),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                state.passed ? DealGoIcons.success : DealGoIcons.userRound,
                color: state.passed ? DealGoColors.brandGreen : Colors.white,
                size: 20,
              ),
              const SizedBox(width: DealGoSpacing.s8),
              if (state.recording) ...[
                HintPill(
                  key: const Key('liveness-recording'),
                  icon: DealGoIcons.circle,
                  text: l10n.kycLivenessRecording,
                  color: DealGoColors.danger,
                ),
                const SizedBox(width: DealGoSpacing.s8),
              ],
              Text(
                step,
                key: const Key('liveness-step'),
                style: const TextStyle(color: Colors.white, fontSize: 18),
              ),
            ],
          ),
          if (hint != null) ...[
            const SizedBox(height: DealGoSpacing.s8),
            Text(
              hint,
              key: const Key('liveness-hint'),
              style: const TextStyle(color: DealGoColors.amber),
            ),
          ],
          if (state.hint == LivenessHint.timeout) ...[
            const SizedBox(height: DealGoSpacing.s8),
            FilledButton.icon(
              key: const Key('liveness-retry'),
              onPressed: onRetry,
              icon: const Icon(DealGoIcons.refresh),
              label: Text(l10n.kycCaptureRetake),
            ),
          ],
        ],
      ),
    );
  }
}
