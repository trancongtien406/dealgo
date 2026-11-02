import 'package:dio/dio.dart';

import '../../../../core/network/api_envelope.dart';
import '../../../../core/network/api_paths.dart';

/// DEC-PROD-048 (DRAFT): source of the admin KYC/KYB switch.
abstract class PartnerRequirementsSource {
  Future<bool> documentsRequired({
    required String accessToken,
    required String role,
  });

  /// t90u: admin setting DRIVER_CAR_EXTRA_DOCS_REQUIRED — whether a car driver must
  /// upload VEHICLE_INSURANCE (also in quick registration). Fails closed (true).
  Future<bool> carExtraDocsRequired({required String accessToken});
}

/// Fixed answer — used by mock mode and tests so they never hit the network.
class FixedPartnerRequirements implements PartnerRequirementsSource {
  const FixedPartnerRequirements({this.required = true, this.carDocs = true});

  final bool required;
  final bool carDocs;

  @override
  Future<bool> carExtraDocsRequired({required String accessToken}) async =>
      carDocs;

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

  @override
  Future<bool> carExtraDocsRequired({required String accessToken}) async {
    try {
      final response = await _dio.get<Object?>(
        ApiPaths.partnerRequirements('DRIVER'),
        queryParameters: const {'vehicleClassCode': 'CAR_4'},
        options: Options(headers: {'Authorization': 'Bearer $accessToken'}),
      );
      final data = requireSuccessData(response.data);
      final docs = data['requiredDocuments'];
      if (docs is! List) return true;
      return docs.contains('VEHICLE_INSURANCE');
    } catch (_) {
      return true;
    }
  }
}
