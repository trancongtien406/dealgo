import 'package:dio/dio.dart';

import '../../../../core/network/api_envelope.dart';
import '../../../../core/network/api_exception.dart';
import '../../../../core/network/api_paths.dart';
import '../../../../core/network/dio_mapper.dart';
import '../models/partner_application_body.dart';
import 'partner_applications_remote_datasource.dart';

class DioPartnerApplicationsRemoteDataSource
    implements PartnerApplicationsRemoteDataSource {
  DioPartnerApplicationsRemoteDataSource({required this._dio});

  final Dio _dio;

  @override
  Future<List<PartnerApplicationView>> listMine(String accessToken) {
    return _request(
      () => _dio.get<Object?>(
        ApiPaths.partnerApplications,
        options: _auth(accessToken),
      ),
      (data) {
        final raw = data['applications'];
        if (raw is! List) {
          throw const ApiException(
            statusCode: 500,
            message: 'Invalid partner applications list',
            errorCode: 'INVALID_RESPONSE',
          );
        }
        return [
          for (final item in raw)
            if (item is Map) _parseApplication(asJsonMap(item)!),
        ];
      },
    );
  }

  @override
  Future<PartnerApplicationView> getMine({
    required String accessToken,
    required String role,
  }) {
    return _request(
      () => _dio.get<Object?>(
        ApiPaths.partnerApplication(role),
        options: _auth(accessToken),
      ),
      _parseApplication,
    );
  }

  @override
  Future<PartnerApplicationView> submit(
    SubmitPartnerApplicationRequest request,
  ) {
    return _request(
      () => _dio.post<Object?>(
        ApiPaths.partnerApplications,
        data: partnerApplicationBodyJson(request),
        options: _auth(request.accessToken),
      ),
      _parseApplication,
    );
  }

  Future<T> _request<T>(
    Future<Response<Object?>> Function() send,
    T Function(Map<String, Object?> data) decode,
  ) async {
    try {
      final response = await send();
      return decode(requireSuccessData(response.data));
    } on DioException catch (error) {
      throw apiExceptionFromDio(error);
    }
  }

  Options _auth(String accessToken) {
    return Options(headers: {'Authorization': 'Bearer $accessToken'});
  }
}

PartnerApplicationView _parseApplication(Map<String, Object?> json) {
  final view = parsePartnerApplication(json);
  if (view == null) {
    throw const ApiException(
      statusCode: 500,
      message: 'Invalid partner application payload',
      errorCode: 'INVALID_RESPONSE',
    );
  }
  return view;
}

typedef DioPartnerApplicationsClient = DioPartnerApplicationsRemoteDataSource;
