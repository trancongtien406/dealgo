import '../../domain/repositories/partner_applications_repository.dart';
import '../datasources/partner_applications_remote_datasource.dart';

class PartnerApplicationsRepositoryImpl
    implements PartnerApplicationsRepository {
  PartnerApplicationsRepositoryImpl(this._remote);

  final PartnerApplicationsRemoteDataSource _remote;

  @override
  Future<List<PartnerApplicationView>> listMine(String accessToken) {
    return _remote.listMine(accessToken);
  }

  @override
  Future<PartnerApplicationView> getMine({
    required String accessToken,
    required String role,
  }) {
    return _remote.getMine(accessToken: accessToken, role: role);
  }

  @override
  Future<PartnerApplicationView> submit(
    SubmitPartnerApplicationRequest request,
  ) {
    return _remote.submit(request);
  }
}
