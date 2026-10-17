class PartnerDocumentInput {
  const PartnerDocumentInput({
    required this.label,
    this.contentType,
    this.contentBase64,
  });

  final String label;
  final String? contentType;
  final String? contentBase64;
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

class PartnerApplicationView {
  const PartnerApplicationView({
    required this.id,
    required this.role,
    required this.status,
    required this.metadata,
    this.reason,
    this.submittedAt,
  });

  final String id;
  final String role;
  final String status;
  final Map<String, Object?> metadata;
  final String? reason;
  final String? submittedAt;
}
