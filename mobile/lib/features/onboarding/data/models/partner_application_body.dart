import '../../domain/entities/partner_application.dart';

Map<String, Object?> partnerApplicationBodyJson(
  SubmitPartnerApplicationRequest request,
) {
  return {
    'role': request.role,
    'metadata': request.metadata,
    if (request.acceptedLegalDocuments.isNotEmpty)
      'acceptedLegalDocuments': [
        for (final doc in request.acceptedLegalDocuments) doc.toJson(),
      ],
    if (request.documents.isNotEmpty)
      'documents': [
        for (final doc in request.documents)
          {
            'kind': doc.kind,
            if (doc.label != null) 'label': doc.label,
            'contentType': doc.contentType,
            'contentBase64': doc.contentBase64,
          },
      ],
  };
}

PartnerApplicationView? parsePartnerApplication(Map<String, Object?> json) {
  final id = json['id'];
  final role = json['role'];
  final status = json['status'];
  if (id is! String || role is! String || status is! String) {
    return null;
  }
  final metadataRaw = json['metadata'];
  final documentsRaw = json['documents'];
  final issuesRaw = json['issues'];
  return PartnerApplicationView(
    id: id,
    role: role,
    status: status,
    metadata: metadataRaw is Map
        ? Map<String, Object?>.from(metadataRaw)
        : <String, Object?>{},
    reason: json['reason'] is String ? json['reason'] as String : null,
    submittedAt: json['submittedAt'] is String
        ? json['submittedAt'] as String
        : null,
    reviewedAt: json['reviewedAt'] is String
        ? json['reviewedAt'] as String
        : null,
    documents: [
      if (documentsRaw is List)
        for (final (position, item) in documentsRaw.indexed)
          if (item is Map)
            PartnerDocumentSummary(
              index: item['index'] is int ? item['index'] as int : position,
              kind: item['kind'] is String ? item['kind'] as String : null,
              contentType: item['contentType'] is String
                  ? item['contentType'] as String
                  : 'application/octet-stream',
              sizeBytes: item['sizeBytes'] is num
                  ? (item['sizeBytes'] as num).toInt()
                  : 0,
              hasFile: item['hasFile'] != false,
            ),
    ],
    issues: [
      if (issuesRaw is List)
        for (final item in issuesRaw)
          if (item is Map &&
              item['section'] is String &&
              item['note'] is String)
            PartnerReviewIssue(
              section: item['section'] as String,
              note: item['note'] as String,
            ),
    ],
  );
}
