import 'dart:io';
import 'dart:typed_data';

import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';

import '../../domain/ocr/document_text_reader.dart';

/// Google ML Kit on-device text recognition (Latin script covers Vietnamese
/// letters well enough for labels/numbers; the applicant confirms values).
class MlKitDocumentTextReader implements DocumentTextReader {
  TextRecognizer? _recognizer;

  @override
  Future<String?> read(Uint8List imageBytes) async {
    if (!(Platform.isAndroid || Platform.isIOS)) return null;
    final dir = await Directory.systemTemp.createTemp('dealgo-ocr');
    final file = File('${dir.path}/doc.jpg');
    try {
      await file.writeAsBytes(imageBytes, flush: true);
      final recognizer = _recognizer ??= TextRecognizer(
        script: TextRecognitionScript.latin,
      );
      final result = await recognizer.processImage(
        InputImage.fromFilePath(file.path),
      );
      return result.text;
    } catch (_) {
      return null; // OCR is a convenience; manual entry still works.
    } finally {
      try {
        await dir.delete(recursive: true);
      } catch (_) {}
    }
  }

  Future<void> close() async => _recognizer?.close();
}
