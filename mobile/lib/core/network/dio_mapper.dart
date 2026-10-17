import 'package:dio/dio.dart';

import 'api_envelope.dart';
import 'api_exception.dart';

ApiException apiExceptionFromDio(DioException error) {
  final status = error.response?.statusCode ?? 0;
  final body = asJsonMap(error.response?.data);
  if (body != null) {
    return errorFromEnvelope(body, statusCode: status);
  }
  return ApiException(
    statusCode: status,
    message: 'Không thể kết nối máy chủ',
    errorCode: status == 0 ? 'NETWORK_ERROR' : 'HTTP_ERROR',
  );
}
