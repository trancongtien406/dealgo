import 'dart:convert';
import 'dart:typed_data';

import 'package:image_picker/image_picker.dart';

class PickedAvatarImage {
  const PickedAvatarImage({required this.bytes, required this.contentType});

  final Uint8List bytes;
  final String contentType;

  String get contentBase64 => base64Encode(bytes);

  String get dataUrl => 'data:$contentType;base64,$contentBase64';
}

abstract interface class AvatarImageSource {
  Future<PickedAvatarImage?> pickFromGallery();
}

class ImagePickerAvatarSource implements AvatarImageSource {
  ImagePickerAvatarSource({ImagePicker? picker})
    : _picker = picker ?? ImagePicker();

  final ImagePicker _picker;

  @override
  Future<PickedAvatarImage?> pickFromGallery() async {
    final file = await _picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 1024,
      maxHeight: 1024,
      imageQuality: 85,
    );
    if (file == null) {
      return null;
    }
    final bytes = await file.readAsBytes();
    final mime = file.mimeType ?? _guessMime(file.path);
    return PickedAvatarImage(bytes: bytes, contentType: mime);
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

class FakeAvatarImageSource implements AvatarImageSource {
  FakeAvatarImageSource({this.nextImage});

  PickedAvatarImage? nextImage;
  int pickCount = 0;

  @override
  Future<PickedAvatarImage?> pickFromGallery() async {
    pickCount++;
    return nextImage;
  }
}
