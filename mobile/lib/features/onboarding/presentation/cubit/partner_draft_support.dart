import 'dart:convert';

import '../../../../core/drafts/draft_store.dart';
import '../document_image_source.dart';
import 'partner_document_draft.dart';

/// Server error for a second submit of an application already under review;
/// the first submit landed, so the client treats it as success.
const partnerAlreadySubmitted = 'PARTNER_APPLICATION_ALREADY_SUBMITTED';

/// One draft per role per signed-in user.
String partnerDraftKey(String role, String owner) =>
    'partner.${role.toLowerCase()}.${base64Url.encode(utf8.encode(owner))}';

/// `{kind: contentType}` of the photos picked in this draft.
Map<String, String> draftDocumentTypes(PartnerDocumentDraft documents) => {
  for (final entry in documents.picked.entries)
    entry.key: entry.value.contentType,
};

/// Decrypts the photos listed in a saved draft; missing ones are skipped.
Future<Map<String, PickedDocumentImage>> loadDraftImages(
  DraftStore store,
  String key,
  Object? docs,
) async {
  final images = <String, PickedDocumentImage>{};
  if (docs is! Map) {
    return images;
  }
  for (final entry in docs.entries) {
    final kind = '${entry.key}';
    final bytes = await store.readBlob(key, kind);
    if (bytes != null && bytes.isNotEmpty) {
      images[kind] = PickedDocumentImage(
        bytes: bytes,
        contentType: '${entry.value}',
      );
    }
  }
  return images;
}

String? draftString(Map<String, Object?> data, String key) {
  final value = data[key];
  return value is String ? value : null;
}

/// A saved draft waiting for the applicant to continue or start over.
class PartnerDraftSnapshot {
  const PartnerDraftSnapshot({
    required this.fields,
    required this.images,
    required this.savedAt,
  });

  final Map<String, Object?> fields;
  final Map<String, PickedDocumentImage> images;
  final DateTime? savedAt;
}
