import 'dart:convert';
import 'dart:typed_data';

import 'package:image_picker/image_picker.dart';

/// A photo picked for a KYC/KYB document slot.
class PickedDocumentImage {
  const PickedDocumentImage({
    required this.bytes,
    required this.contentType,
    this.checks = const {},
  });

  final Uint8List bytes;
  final String contentType;

  /// t52u: device-side capture checks (metadata key → passed), e.g.
  /// `captureIdFrontQualityOk`. Empty for gallery picks. Advisory only.
  final Map<String, bool> checks;

  String get contentBase64 => base64Encode(bytes);
}

/// Captures document photos; swapped for [FakeDocumentImageSource] in tests.
abstract interface class DocumentImageSource {
  Future<PickedDocumentImage?> pick({required bool camera, bool front = false});
}

class ImagePickerDocumentSource implements DocumentImageSource {
  ImagePickerDocumentSource({ImagePicker? picker})
    : _picker = picker ?? ImagePicker();

  final ImagePicker _picker;

  @override
  Future<PickedDocumentImage?> pick({
    required bool camera,
    bool front = false,
  }) async {
    // 1600px / q80 keeps a photo of an ID card readable at well under the
    // default 4 MB UPLOAD_MAX_FILE_KB limit.
    final file = await _picker.pickImage(
      source: camera ? ImageSource.camera : ImageSource.gallery,
      preferredCameraDevice: front ? CameraDevice.front : CameraDevice.rear,
      maxWidth: 1600,
      maxHeight: 1600,
      imageQuality: 80,
    );
    if (file == null) {
      return null;
    }
    final bytes = await file.readAsBytes();
    return PickedDocumentImage(
      bytes: bytes,
      contentType: file.mimeType ?? _guessMime(file.path),
    );
  }

  String _guessMime(String path) {
    final lower = path.toLowerCase();
    if (lower.endsWith('.png')) {
      return 'image/png';
    }
    if (lower.endsWith('.webp')) {
      return 'image/webp';
    }
    return 'image/jpeg';
  }
}

class FakeDocumentImageSource implements DocumentImageSource {
  FakeDocumentImageSource({this.nextImage});

  PickedDocumentImage? nextImage;
  final calls = <({bool camera, bool front})>[];

  @override
  Future<PickedDocumentImage?> pick({
    required bool camera,
    bool front = false,
  }) async {
    calls.add((camera: camera, front: front));
    return nextImage;
  }
}
