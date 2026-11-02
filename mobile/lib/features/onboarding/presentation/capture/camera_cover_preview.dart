import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Upright (portrait) size of a camera stream. Sensors report landscape
/// (e.g. 1920×1080) even when the UI is portrait.
Size portraitPreviewSize(Size sensor) =>
    sensor.width > sensor.height ? Size(sensor.height, sensor.width) : sensor;

/// Part of an upright frame (0..1 fractions) that stays visible when the
/// frame is scaled with [BoxFit.cover] into a box of [boxAspect] (w / h).
Rect coverCrop(Size frame, double boxAspect) {
  final frameAspect = frame.width / frame.height;
  if (frameAspect > boxAspect) {
    final w = boxAspect / frameAspect;
    return Rect.fromLTWH((1 - w) / 2, 0, w, 1);
  }
  final h = frameAspect / boxAspect;
  return Rect.fromLTWH(0, (1 - h) / 2, 1, h);
}

/// Camera preview that fills its box like [BoxFit.cover]: keeps the stream's
/// real aspect (no stretching) and clips the overflow.
class CameraCoverPreview extends StatelessWidget {
  const CameraCoverPreview({
    required this.previewSize,
    required this.child,
    super.key,
  });

  /// Upright preview size (see [portraitPreviewSize]).
  final Size previewSize;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return ClipRect(
      child: FittedBox(
        fit: BoxFit.cover,
        child: SizedBox(
          key: const Key('camera-cover-preview'),
          width: previewSize.width,
          height: previewSize.height,
          child: child,
        ),
      ),
    );
  }
}

/// Preview box with the controller's real aspect, overlay drawn in the same
/// box so the guide matches what the camera (and the frame checks) see.
class CameraAspectPreview extends StatelessWidget {
  const CameraAspectPreview({
    required this.controller,
    required this.overlay,
    super.key,
  });

  final CameraController controller;
  final Widget overlay;

  @override
  Widget build(BuildContext context) {
    final size = portraitPreviewSize(
      controller.value.previewSize ?? const Size(1080, 1920),
    );
    return Center(
      child: AspectRatio(
        key: const Key('camera-aspect-preview'),
        aspectRatio: size.width / size.height,
        child: Stack(
          fit: StackFit.expand,
          children: [
            CameraCoverPreview(
              previewSize: size,
              child: CameraPreview(controller),
            ),
            overlay,
          ],
        ),
      ),
    );
  }
}

/// Black capture app bar with readable white title/icons and light status bar.
AppBar captureAppBar(String title) => AppBar(
  backgroundColor: Colors.black,
  foregroundColor: Colors.white,
  surfaceTintColor: Colors.transparent,
  iconTheme: const IconThemeData(color: Colors.white),
  systemOverlayStyle: SystemUiOverlayStyle.light,
  title: Text(
    title,
    maxLines: 2,
    softWrap: true,
    style: const TextStyle(
      color: Colors.white,
      fontSize: 17,
      fontWeight: FontWeight.w600,
    ),
  ),
);
