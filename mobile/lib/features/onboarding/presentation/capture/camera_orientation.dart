import 'dart:io';

import 'package:camera/camera.dart';
import 'package:flutter/services.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';

const _orientationDegrees = <DeviceOrientation, int>{
  DeviceOrientation.portraitUp: 0,
  DeviceOrientation.landscapeLeft: 90,
  DeviceOrientation.portraitDown: 180,
  DeviceOrientation.landscapeRight: 270,
};

/// Rotation required by ML Kit for a raw camera frame.
///
/// Android camera frames need device-orientation compensation. iOS already
/// supplies frames in the sensor orientation expected by ML Kit.
InputImageRotation? inputImageRotation({
  required CameraDescription camera,
  required DeviceOrientation deviceOrientation,
}) {
  if (!Platform.isAndroid && !Platform.isIOS) return null;
  return InputImageRotationValue.fromRawValue(
    cameraRotationDegrees(
      camera: camera,
      deviceOrientation: deviceOrientation,
      isIOS: Platform.isIOS,
    ),
  );
}

int cameraRotationDegrees({
  required CameraDescription camera,
  required DeviceOrientation deviceOrientation,
  required bool isIOS,
}) {
  final sensor = camera.sensorOrientation;
  if (isIOS) return sensor;
  final device = _orientationDegrees[deviceOrientation]!;
  return camera.lensDirection == CameraLensDirection.front
      ? (sensor + device) % 360
      : (sensor - device + 360) % 360;
}

/// Size of [image] after ML Kit applies [rotation].
({double width, double height}) uprightFrameSize(
  CameraImage image,
  InputImageRotation rotation,
) {
  final quarterTurn =
      rotation == InputImageRotation.rotation90deg ||
      rotation == InputImageRotation.rotation270deg;
  return quarterTurn
      ? (width: image.height.toDouble(), height: image.width.toDouble())
      : (width: image.width.toDouble(), height: image.height.toDouble());
}
