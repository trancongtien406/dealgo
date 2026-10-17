import '../entities/partner_application.dart';

abstract interface class PartnerApplicationsRepository {
  Future<List<PartnerApplicationView>> listMine(String accessToken);

  Future<PartnerApplicationView> getMine({
    required String accessToken,
    required String role,
  });

  Future<PartnerApplicationView> submit(
    SubmitPartnerApplicationRequest request,
  );
}
