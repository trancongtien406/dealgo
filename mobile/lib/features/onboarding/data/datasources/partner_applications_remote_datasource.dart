import '../../domain/entities/partner_application.dart';

export '../../domain/entities/partner_application.dart';

abstract interface class PartnerApplicationsRemoteDataSource {
  Future<List<PartnerApplicationView>> listMine(String accessToken);

  Future<PartnerApplicationView> getMine({
    required String accessToken,
    required String role,
  });

  Future<PartnerApplicationView> submit(
    SubmitPartnerApplicationRequest request,
  );
}

/// Backward-compatible alias used by mocks, tests, and DI overrides.
typedef PartnerApplicationsClient = PartnerApplicationsRemoteDataSource;
