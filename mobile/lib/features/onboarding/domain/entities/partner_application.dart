/// One file sent with a partner application (DEC-PROD-020).
///
/// [kind] is a backend document code such as `ID_FRONT` or `BUSINESS_LICENSE`.
class PartnerDocumentInput {
  const PartnerDocumentInput({
    required this.kind,
    required this.contentType,
    required this.contentBase64,
    this.label,
  });

  final String kind;
  final String contentType;
  final String contentBase64;
  final String? label;
}

class SubmitPartnerApplicationRequest {
  const SubmitPartnerApplicationRequest({
    required this.accessToken,
    required this.role,
    required this.metadata,
    this.documents = const [],
  });

  final String accessToken;
  final String role;
  final Map<String, Object?> metadata;
  final List<PartnerDocumentInput> documents;
}

/// Stored document summary as returned by the server (no storage key).
class PartnerDocumentSummary {
  const PartnerDocumentSummary({
    required this.index,
    required this.kind,
    required this.contentType,
    required this.sizeBytes,
    required this.hasFile,
  });

  final int index;
  final String? kind;
  final String contentType;
  final int sizeBytes;
  final bool hasFile;
}

/// One section ops asked the applicant to fix, with a note.
class PartnerReviewIssue {
  const PartnerReviewIssue({required this.section, required this.note});

  final String section;
  final String note;
}

class PartnerApplicationView {
  const PartnerApplicationView({
    required this.id,
    required this.role,
    required this.status,
    required this.metadata,
    this.reason,
    this.submittedAt,
    this.reviewedAt,
    this.documents = const [],
    this.issues = const [],
  });

  final String id;
  final String role;
  final String status;
  final Map<String, Object?> metadata;
  final String? reason;
  final String? submittedAt;
  final String? reviewedAt;
  final List<PartnerDocumentSummary> documents;
  final List<PartnerReviewIssue> issues;

  /// Kinds that already have stored bytes on the server.
  Set<String> get storedKinds => {
    for (final doc in documents)
      if (doc.hasFile && doc.kind != null) doc.kind!,
  };
}
