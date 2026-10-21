import '../../domain/entities/partner_application.dart';
import '../../domain/entities/partner_documents.dart';
import '../document_image_source.dart';

/// Error codes a KYC/KYB submit can end with; pages map them to l10n copy.
abstract final class PartnerSubmitError {
  static const sessionExpired = 'SESSION_EXPIRED';
  static const network = 'NETWORK';
  static const missingDocuments = 'PARTNER_DOCUMENTS_REQUIRED';
}

/// Local document picks plus what the server already stores.
///
/// A kind counts as present when it was picked in this session, or when the
/// server has its bytes and ops did not flag it for re-capture. Only picks are
/// uploaded: the server keeps prior files that are not re-sent.
class PartnerDocumentDraft {
  const PartnerDocumentDraft({
    this.picked = const {},
    this.stored = const {},
    this.flagged = const {},
  });

  final Map<String, PickedDocumentImage> picked;
  final Set<String> stored;
  final Set<String> flagged;

  bool has(String kind) =>
      picked.containsKey(kind) ||
      (stored.contains(kind) && !flagged.contains(kind));

  bool isFlagged(String kind) =>
      flagged.contains(kind) && !picked.containsKey(kind);

  bool hasAll(Iterable<String> kinds) => kinds.every(has);

  PartnerDocumentDraft attach(String kind, PickedDocumentImage image) {
    return PartnerDocumentDraft(
      picked: {...picked, kind: image},
      stored: stored,
      flagged: flagged,
    );
  }

  PartnerDocumentDraft detach(String kind) {
    return PartnerDocumentDraft(
      picked: {...picked}..remove(kind),
      stored: stored,
      flagged: flagged,
    );
  }

  PartnerDocumentDraft flag(Iterable<String> sections) {
    final kinds = flaggedDocumentKinds(sections);
    return PartnerDocumentDraft(
      picked: {...picked}..removeWhere((kind, _) => kinds.contains(kind)),
      stored: stored,
      flagged: kinds,
    );
  }

  PartnerDocumentDraft synced(Set<String> serverKinds) {
    return PartnerDocumentDraft(stored: serverKinds);
  }

  List<PartnerDocumentInput> uploads(List<String> order) {
    return [
      for (final kind in order)
        if (picked[kind] case final image?)
          PartnerDocumentInput(
            kind: kind,
            contentType: image.contentType,
            contentBase64: image.contentBase64,
          ),
    ];
  }
}

String? metadataText(Map<String, Object?> metadata, String key) {
  final value = metadata[key];
  if (value is String && value.trim().isNotEmpty) {
    return value;
  }
  if (value is num) {
    return value.toString();
  }
  return null;
}
