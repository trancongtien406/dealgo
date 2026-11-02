import 'capture_config.dart';

import 'dart:io';

import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/design_system/tokens/dealgo_tokens.dart';
import '../../../../l10n/app_localizations.dart';
import '../../domain/entities/partner_documents.dart';
import '../document_image_source.dart';
import 'camera_cover_preview.dart';
import 'camera_frames.dart';
import 'capture_hint.dart';
import 'capture_quality.dart';
import 'document_auto_capture_cubit.dart';
import 'frame_gate.dart';
import 'smart_capture.dart';

/// t53u: rear camera, no shutter. The frame gate auto-shoots when the card is
/// fully inside the guide, sharp, lit and glare-free; then advances to the
/// next kind (front → back). Pops `Map<kind, PickedDocumentImage>`.
class DocumentCapturePage extends StatelessWidget {
  const DocumentCapturePage({required this.kinds, super.key});

  final List<String> kinds;

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => DocumentAutoCaptureCubit(kinds),
      child: const _DocumentCaptureView(),
    );
  }
}

class _DocumentCaptureView extends StatefulWidget {
  const _DocumentCaptureView();

  @override
  State<_DocumentCaptureView> createState() => _DocumentCaptureViewState();
}

class _DocumentCaptureViewState extends State<_DocumentCaptureView> {
  static const _frameInterval = CaptureConfig.cardFrameInterval;
  CameraController? _controller;
  bool _failed = false;
  DateTime _lastFrame = DateTime.fromMillisecondsSinceEpoch(0);
  LumaFrame? _previous;

  @override
  void initState() {
    super.initState();
    _open();
  }

  Future<void> _open() async {
    try {
      final cameras = await availableCameras();
      final back = cameras.firstWhere(
        (c) => c.lensDirection == CameraLensDirection.back,
        orElse: () => cameras.first,
      );
      final controller = CameraController(
        back,
        ResolutionPreset.high,
        enableAudio: false,
        imageFormatGroup: Platform.isIOS
            ? ImageFormatGroup.bgra8888
            : ImageFormatGroup.yuv420,
      );
      await controller.initialize();
      if (!mounted) {
        await controller.dispose();
        return;
      }
      setState(() => _controller = controller);
      await _startStream();
    } catch (_) {
      if (mounted) setState(() => _failed = true);
    }
  }

  Future<void> _startStream() async {
    final controller = _controller;
    if (controller == null || controller.value.isStreamingImages) return;
    _previous = null;
    await controller.startImageStream(_onFrame);
  }

  void _onFrame(CameraImage image) {
    final now = DateTime.now();
    if (!mounted || now.difference(_lastFrame) < _frameInterval) return;
    _lastFrame = now;
    final frame = lumaOf(image);
    if (frame == null) return;
    final hint = evaluateCardFrame(frame, previous: _previous);
    // Keep a copy: the camera reuses its buffers.
    _previous = LumaFrame(
      bytes: Uint8List.fromList(frame.bytes),
      width: frame.width,
      height: frame.height,
      rowStride: frame.rowStride,
      pixelStride: frame.pixelStride,
      offset: frame.offset,
    );
    context.read<DocumentAutoCaptureCubit>().onFrame(hint);
  }

  Future<void> _shoot(String kind) async {
    final controller = _controller;
    final cubit = context.read<DocumentAutoCaptureCubit>();
    if (controller == null) return;
    try {
      if (controller.value.isStreamingImages) {
        await controller.stopImageStream();
      }
      final file = await controller.takePicture();
      final prepared = await compute(prepareIdPhoto, await file.readAsBytes());
      if (!mounted) return;
      cubit.onShot(
        prepared?.report,
        prepared == null
            ? null
            : PickedDocumentImage(
                bytes: prepared.jpeg,
                contentType: 'image/jpeg',
                checks: {
                  CaptureMetadataKeys.qualityOk(kind): prepared.report.ok,
                },
              ),
      );
    } catch (_) {
      if (mounted) cubit.onShot(null, null);
    }
    if (mounted && !cubit.state.done) await _startStream();
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final controller = _controller;
    return BlocConsumer<DocumentAutoCaptureCubit, DocumentAutoCaptureState>(
      listenWhen: (a, b) => a.phase != b.phase,
      listener: (context, state) {
        if (state.phase == AutoCapturePhase.shooting && state.kind != null) {
          _shoot(state.kind!);
        } else if (state.done) {
          Navigator.of(context).pop(state.results);
        }
      },
      builder: (context, state) {
        final kind = state.kind ?? state.kinds.last;
        final isBack =
            kind == PartnerDocumentKind.idBack ||
            kind == PartnerDocumentKind.repIdBack;
        return Scaffold(
          backgroundColor: Colors.black,
          appBar: captureAppBar(
            isBack ? l10n.kycCaptureBackTitle : l10n.kycCaptureFrontTitle,
          ),
          body: SafeArea(
            child: _failed
                ? Center(
                    child: Text(
                      l10n.kycCaptureCameraError,
                      style: const TextStyle(color: Colors.white),
                    ),
                  )
                : Stack(
                    fit: StackFit.expand,
                    children: [
                      // The guide lives inside the preview box: it is 88% of the
                      // preview width, the same region CardGuide checks.
                      if (controller != null && controller.value.isInitialized)
                        CameraAspectPreview(
                          controller: controller,
                          overlay: IgnorePointer(
                            child: _CardFrame(ready: state.stableFrames > 0),
                          ),
                        )
                      else ...[
                        const Center(child: CircularProgressIndicator()),
                        IgnorePointer(
                          child: _CardFrame(ready: state.stableFrames > 0),
                        ),
                      ],
                      Positioned(
                        left: 0,
                        right: 0,
                        bottom: DealGoSpacing.s24,
                        child: Center(child: CaptureHintChip(hint: state.hint)),
                      ),
                    ],
                  ),
          ),
        );
      },
    );
  }
}

/// ID-1 card ratio (85.6 × 54 mm) guide; turns green while frames pass.
class _CardFrame extends StatelessWidget {
  const _CardFrame({required this.ready});

  final bool ready;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: FractionallySizedBox(
        widthFactor: 0.88,
        child: AspectRatio(
          aspectRatio: 85.6 / 54,
          child: DecoratedBox(
            decoration: BoxDecoration(
              border: Border.all(
                color: ready ? DealGoColors.brandGreen : Colors.white70,
                width: 3,
              ),
              borderRadius: BorderRadius.circular(DealGoRadius.card),
            ),
          ),
        ),
      ),
    );
  }
}
