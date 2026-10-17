import 'package:dio/dio.dart';

import '../../../../core/network/api_envelope.dart';
import '../../../../core/network/api_exception.dart';
import '../../../../core/network/api_paths.dart';
import '../../../../core/network/dio_mapper.dart';
import 'partner_applications_remote_datasource.dart';

class DioPartnerApplicationsRemoteDataSource implements PartnerApplicationsRemoteDataSource {
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
        data: {
          'role': request.role,
          'metadata': request.metadata,
          if (request.documents.isNotEmpty)
            'documents': [
              for (final doc in request.documents)
                {
                  'label': doc.label,
                  if (doc.contentType != null) 'contentType': doc.contentType,
                  if (doc.contentBase64 != null)
                    'contentBase64': doc.contentBase64,
                },
            ],
        },
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
  final id = json['id'];
  final role = json['role'];
  final status = json['status'];
  if (id is! String || role is! String || status is! String) {
    throw const ApiException(
      statusCode: 500,
      message: 'Invalid partner application payload',
      errorCode: 'INVALID_RESPONSE',
    );
  }
  final metadataRaw = json['metadata'];
  final metadata = <String, Object?>{};
  if (metadataRaw is Map) {
    metadata.addAll(Map<String, Object?>.from(metadataRaw));
  }
  return PartnerApplicationView(
    id: id,
    role: role,
    status: status,
    metadata: metadata,
    reason: json['reason'] as String?,
    submittedAt: json['submittedAt'] as String?,
  );
}

typedef DioPartnerApplicationsClient = DioPartnerApplicationsRemoteDataSource;
