import '../entities/partner_application.dart';
import '../repositories/partner_applications_repository.dart';

class SubmitPartnerApplication {
  const SubmitPartnerApplication(this._repository);

  final PartnerApplicationsRepository _repository;

  Future<PartnerApplicationView> call(SubmitPartnerApplicationRequest request) {
    return _repository.submit(request);
  }
}
