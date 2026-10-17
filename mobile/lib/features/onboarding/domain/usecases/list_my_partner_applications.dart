import '../entities/partner_application.dart';
import '../repositories/partner_applications_repository.dart';

class ListMyPartnerApplications {
  const ListMyPartnerApplications(this._repository);

  final PartnerApplicationsRepository _repository;

  Future<List<PartnerApplicationView>> call(String accessToken) {
    return _repository.listMine(accessToken);
  }
}
