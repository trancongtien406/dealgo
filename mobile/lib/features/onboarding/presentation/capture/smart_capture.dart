import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../domain/entities/partner_documents.dart';
import '../document_image_source.dart';
import 'document_capture_page.dart';
import 'face_liveness_page.dart';

/// Metadata keys the capture flow attaches (flat scalars so the backend's
/// metadata sanitizer keeps them). Admin shows them as "device-reported".
abstract final class CaptureMetadataKeys {
  static const faceDetected = 'captureFaceDetected';
  static const livenessPassed = 'captureLivenessPassed';
  static const livenessVideo = 'captureLivenessVideo';

  static String qualityOk(String kind) => switch (kind) {
    PartnerDocumentKind.idFront => 'captureIdFrontQualityOk',
    PartnerDocumentKind.idBack => 'captureIdBackQualityOk',
    PartnerDocumentKind.repIdFront => 'captureRepIdFrontQualityOk',
    PartnerDocumentKind.repIdBack => 'captureRepIdBackQualityOk',
    _ => 'capture${kind}QualityOk',
  };
}

/// Guided in-app camera for ID front/back and the face (t52u). Optional: when
/// not provided the document slot falls back to [DocumentImageSource].
///
/// t53u: fully automatic. Returns every kind it captured: ID front also
/// auto-advances to the back; the face flow adds the liveness clip.
abstract interface class SmartCaptureLauncher {
  bool supports(String kind);
  Future<Map<String, PickedDocumentImage>?> capture(
    BuildContext context, {
    required String kind,
  });
}

/// Kinds one capture session walks through, starting from [kind].
List<String> smartCaptureSequence(String kind) => switch (kind) {
  PartnerDocumentKind.idFront => const [
    PartnerDocumentKind.idFront,
    PartnerDocumentKind.idBack,
  ],
  PartnerDocumentKind.repIdFront => const [
    PartnerDocumentKind.repIdFront,
    PartnerDocumentKind.repIdBack,
  ],
  _ => [kind],
};

class CameraSmartCaptureLauncher implements SmartCaptureLauncher {
  const CameraSmartCaptureLauncher();

  static const _idKinds = {
    PartnerDocumentKind.idFront,
    PartnerDocumentKind.idBack,
    PartnerDocumentKind.repIdFront,
    PartnerDocumentKind.repIdBack,
  };

  @override
  bool supports(String kind) =>
      _idKinds.contains(kind) || kind == PartnerDocumentKind.selfie;

  @override
  Future<Map<String, PickedDocumentImage>?> capture(
    BuildContext context, {
    required String kind,
  }) {
    final route = MaterialPageRoute<Map<String, PickedDocumentImage>>(
      fullscreenDialog: true,
      builder: (_) => kind == PartnerDocumentKind.selfie
          ? const FaceLivenessPage()
          : DocumentCapturePage(kinds: smartCaptureSequence(kind)),
    );
    return Navigator.of(context).push(route);
  }
}

/// The launcher from the widget tree, or null (tests, or a build without it).
SmartCaptureLauncher? maybeSmartCaptureLauncher(BuildContext context) {
  try {
    return Provider.of<SmartCaptureLauncher>(context, listen: false);
  } on ProviderNotFoundException {
    return null;
  }
}
