import 'package:dio/dio.dart';

import '../../../core/network/api_envelope.dart';
import '../../../core/network/dio_mapper.dart';
import '../domain/payment_models.dart';

/// Customer checkout endpoints. Amounts are always computed by the server.
abstract interface class PaymentApi {
  Future<List<PaymentMethodOption>> listMethods({
    required String accessToken,
    required String service,
  });

  Future<PaymentCheckoutView> start({
    required String accessToken,
    required String entityType,
    required String entityId,
    required String methodCode,
  });

  Future<PaymentCheckoutView> status({
    required String accessToken,
    required String entityType,
    required String entityId,
  });
}

String paymentPathFor(String entityType, String entityId) {
  final id = Uri.encodeComponent(entityId);
  return entityType == 'RIDE'
      ? '/v1/rides/$id/payment'
      : '/v1/food/orders/$id/payment';
}

class DioPaymentApi implements PaymentApi {
  DioPaymentApi(this.dio);

  final Dio dio;

  Options _bearer(String token) =>
      Options(headers: {'Authorization': 'Bearer $token'});

  @override
  Future<List<PaymentMethodOption>> listMethods({
    required String accessToken,
    required String service,
  }) async {
    try {
      final res = await dio.get<Object?>(
        '/v1/payments/methods',
        queryParameters: {'service': service},
        options: _bearer(accessToken),
      );
      final payload = readSuccessPayload(res.data);
      final list = payload is List ? payload : const [];
      return [
        for (final item in list)
          if (asJsonMap(item) case final map?)
            PaymentMethodOption.fromJson(map),
      ];
    } on DioException catch (e) {
      throw apiExceptionFromDio(e);
    }
  }

  @override
  Future<PaymentCheckoutView> start({
    required String accessToken,
    required String entityType,
    required String entityId,
    required String methodCode,
  }) async {
    try {
      final res = await dio.post<Object?>(
        paymentPathFor(entityType, entityId),
        data: {'methodCode': methodCode},
        options: _bearer(accessToken),
      );
      return PaymentCheckoutView.fromJson(requireSuccessData(res.data));
    } on DioException catch (e) {
      throw apiExceptionFromDio(e);
    }
  }

  @override
  Future<PaymentCheckoutView> status({
    required String accessToken,
    required String entityType,
    required String entityId,
  }) async {
    try {
      final res = await dio.get<Object?>(
        paymentPathFor(entityType, entityId),
        options: _bearer(accessToken),
      );
      return PaymentCheckoutView.fromJson(requireSuccessData(res.data));
    } on DioException catch (e) {
      throw apiExceptionFromDio(e);
    }
  }
}
