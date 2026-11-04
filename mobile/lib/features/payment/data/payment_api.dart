import 'package:dio/dio.dart';

import '../../../core/network/api_envelope.dart';
import '../../../core/network/dio_mapper.dart';
import '../domain/payment_models.dart';
import 'payment_methods_cache.dart';

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
  DioPaymentApi(this.dio, {PaymentMethodsCache? methodsCache})
    : _methodsCache = methodsCache ?? sharedMethodsCache;

  /// Shared by every `DioPaymentApi` the UI creates on demand, so a tile that
  /// is rebuilt after scrolling does not hit the network again.
  static final PaymentMethodsCache sharedMethodsCache = PaymentMethodsCache();

  final Dio dio;
  final PaymentMethodsCache _methodsCache;

  Options _bearer(String token) =>
      Options(headers: {'Authorization': 'Bearer $token'});

  @override
  Future<List<PaymentMethodOption>> listMethods({
    required String accessToken,
    required String service,
  }) {
    return _methodsCache.read(
      service,
      () => _fetchMethods(accessToken: accessToken, service: service),
    );
  }

  void invalidateMethods([String? service]) =>
      _methodsCache.invalidate(service);

  Future<List<PaymentMethodOption>> _fetchMethods({
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
