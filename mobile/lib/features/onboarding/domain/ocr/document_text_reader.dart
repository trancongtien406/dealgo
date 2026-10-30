import 'dart:typed_data';

/// Reads printed text from a document photo on the device (no network).
abstract interface class DocumentTextReader {
  /// Returns recognized text, or null when the photo could not be read.
  Future<String?> read(Uint8List imageBytes);
}
