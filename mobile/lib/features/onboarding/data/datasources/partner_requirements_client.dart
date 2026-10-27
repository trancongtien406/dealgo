import 'package:dio/dio.dart';

import '../../../../core/network/api_envelope.dart';
import '../../../../core/network/api_paths.dart';

/// DEC-PROD-048 (DRAFT): source of the admin KYC/KYB switch.
abstract class PartnerRequirementsSource {
  Future<bool> documentsRequired({
    required String accessToken,
    required String role,
  });
}

/// Fixed answer — used by mock mode and tests so they never hit the network.
class FixedPartnerRequirements implements PartnerRequirementsSource {
  const FixedPartnerRequirements({this.required = true});

  final bool required;

  @override
  Future<bool> documentsRequired({
    required String accessToken,
    required String role,
  }) async => required;
}

/// DEC-PROD-048 (DRAFT): reads the admin switch that waives KYC/KYB documents.
///
/// Fails closed: any error or malformed payload means documents are required.
class PartnerRequirementsClient implements PartnerRequirementsSource {
  PartnerRequirementsClient(this._dio);

  final Dio _dio;

  @override
  Future<bool> documentsRequired({
    required String accessToken,
    required String role,
  }) async {
    try {
      final response = await _dio.get<Object?>(
        ApiPaths.partnerRequirements(role),
        options: Options(headers: {'Authorization': 'Bearer $accessToken'}),
      );
      final data = requireSuccessData(response.data);
      return data['documentsRequired'] != false;
    } catch (_) {
      return true;
    }
  }
}
