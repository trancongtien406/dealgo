import '../../../../core/network/api_exception.dart';
import 'partner_applications_remote_datasource.dart';

class FakePartnerApplicationsClient implements PartnerApplicationsClient {
  FakePartnerApplicationsClient({
    this.applications = const [],
    this.submitError,
    this.onSubmit,
  });

  List<PartnerApplicationView> applications;
  Object? submitError;
  PartnerApplicationView Function(SubmitPartnerApplicationRequest request)?
  onSubmit;

  final submitCalls = <SubmitPartnerApplicationRequest>[];
  final listCalls = <String>[];

  @override
  Future<List<PartnerApplicationView>> listMine(String accessToken) async {
    listCalls.add(accessToken);
    return List.unmodifiable(applications);
  }

  @override
  Future<PartnerApplicationView> getMine({
    required String accessToken,
    required String role,
  }) async {
    for (final app in applications) {
      if (app.role == role) {
        return app;
      }
    }
    throw const ApiException(
      statusCode: 404,
      message: 'Partner application not found',
      errorCode: 'PARTNER_APPLICATION_NOT_FOUND',
    );
  }

  @override
  Future<PartnerApplicationView> submit(
    SubmitPartnerApplicationRequest request,
  ) async {
    submitCalls.add(request);
    final error = submitError;
    if (error != null) {
      throw error;
    }
    final handler = onSubmit;
    if (handler != null) {
      return handler(request);
    }
    PartnerApplicationView? previous;
    for (final app in applications) {
      if (app.role == request.role) {
        previous = app;
      }
    }
    final sentKinds = {for (final doc in request.documents) doc.kind};
    final kept = [
      for (final doc in previous?.documents ?? const <PartnerDocumentSummary>[])
        if (doc.hasFile && !sentKinds.contains(doc.kind)) doc,
    ];
    final view = PartnerApplicationView(
      id: 'app-${request.role.toLowerCase()}',
      role: request.role,
      status: 'SUBMITTED',
      metadata: request.metadata,
      submittedAt: DateTime.now().toUtc().toIso8601String(),
      documents: [
        for (final (index, doc) in [
          ...kept.map((d) => (d.kind, d.contentType, d.sizeBytes)),
          ...request.documents.map(
            (d) => (d.kind, d.contentType, d.contentBase64.length * 3 ~/ 4),
          ),
        ].indexed)
          PartnerDocumentSummary(
            index: index,
            kind: doc.$1,
            contentType: doc.$2,
            sizeBytes: doc.$3,
            hasFile: true,
          ),
      ],
    );
    applications = [
      for (final app in applications)
        if (app.role != request.role) app,
      view,
    ];
    return view;
  }
}
