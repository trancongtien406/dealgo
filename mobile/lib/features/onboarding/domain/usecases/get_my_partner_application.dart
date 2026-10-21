import '../../../../core/network/api_exception.dart';
import '../entities/partner_application.dart';
import '../repositories/partner_applications_repository.dart';

/// Loads the caller's application for [role]; null when none exists yet.
class GetMyPartnerApplication {
  const GetMyPartnerApplication(this._repository);

  final PartnerApplicationsRepository _repository;

  Future<PartnerApplicationView?> call({
    required String accessToken,
    required String role,
  }) async {
    try {
      return await _repository.getMine(accessToken: accessToken, role: role);
    } on ApiException catch (error) {
      if (error.statusCode == 404) {
        return null;
      }
      rethrow;
    }
  }
}
