import '../../domain/entities/partner_application.dart';

Map<String, Object?> partnerApplicationBodyJson(
  SubmitPartnerApplicationRequest request,
) {
  return {
    'role': request.role,
    'metadata': request.metadata,
    if (request.documents.isNotEmpty)
      'documents': [
        for (final doc in request.documents)
          {
            'label': doc.label,
            if (doc.contentType != null) 'contentType': doc.contentType,
            if (doc.contentBase64 != null) 'contentBase64': doc.contentBase64,
          },
      ],
  };
}
