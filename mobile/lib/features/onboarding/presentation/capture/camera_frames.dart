import 'package:camera/camera.dart';

import 'frame_gate.dart';

/// Wraps a camera frame's luma in place (Android Y plane / iOS BGRA green byte).
LumaFrame? lumaOf(CameraImage image) {
  if (image.planes.isEmpty) return null;
  final plane = image.planes.first;
  final bgra = image.format.group == ImageFormatGroup.bgra8888;
  return LumaFrame(
    bytes: plane.bytes,
    width: image.width,
    height: image.height,
    rowStride: plane.bytesPerRow,
    pixelStride: bgra ? 4 : (plane.bytesPerPixel ?? 1),
    offset: bgra ? 1 : 0,
  );
}
