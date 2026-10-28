import 'package:dio/dio.dart';

import '../../../core/network/api_envelope.dart';
import '../../../core/network/dio_mapper.dart';
import '../domain/payment_models.dart';

/// What the assigned driver must collect for a job (server-computed).
class DriverCollection {
  const DriverCollection({
    required this.methodCode,
    required this.status,
    required this.paidOnlineVnd,
    required this.cashToCollectVnd,
  });

  factory DriverCollection.fromJson(Map<String, Object?> json) =>
      DriverCollection(
        methodCode: json['methodCode'] as String? ?? cashMethodCode,
        status: paymentStatusFrom(json['status']),
        paidOnlineVnd: (json['paidOnlineVnd'] as num?)?.toInt() ?? 0,
        cashToCollectVnd: (json['cashToCollectVnd'] as num?)?.toInt() ?? 0,
      );

  final String methodCode;
  final PaymentCheckoutStatus status;
  final int paidOnlineVnd;
  final int cashToCollectVnd;

  bool get fullyPaidOnline => paidOnlineVnd > 0 && cashToCollectVnd == 0;

  /// Online chosen but not captured yet: the driver may still have to collect cash.
  bool get onlinePending =>
      methodCode != cashMethodCode && status == PaymentCheckoutStatus.pending;
}

typedef DriverCollectionLoader = Future<DriverCollection> Function({
  required String accessToken,
  required String entityType,
  required String entityId,
});

String driverCollectionPath(String entityType, String entityId) {
  final id = Uri.encodeComponent(entityId);
  return entityType == 'RIDE'
      ? '/v1/rides/$id/collection'
      : '/v1/food/orders/$id/collection';
}

DriverCollectionLoader dioDriverCollectionLoader(Dio dio) =>
    ({required accessToken, required entityType, required entityId}) async {
      try {
        final res = await dio.get<Object?>(
          driverCollectionPath(entityType, entityId),
          options: Options(headers: {'Authorization': 'Bearer $accessToken'}),
        );
        return DriverCollection.fromJson(requireSuccessData(res.data));
      } on DioException catch (e) {
        throw apiExceptionFromDio(e);
      }
    };

/// Brand name for a method code; CASH is localized by the caller.
String paymentMethodBrand(String code) => switch (code) {
  'MOMO' => 'MoMo',
  'ZALOPAY' => 'ZaloPay',
  'VNPAY' || 'VNPAY_ATM' => 'VNPAY',
  'APPLE_PAY' => 'Apple Pay',
  'SHOPEEPAY' => 'ShopeePay',
  'INTERNATIONAL_CARD' => 'Visa/Mastercard',
  'DEALGO_WALLET' => 'Ví DealGo',
  _ => code,
};
