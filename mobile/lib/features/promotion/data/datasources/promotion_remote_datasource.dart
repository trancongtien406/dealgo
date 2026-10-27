import 'package:dio/dio.dart';

import '../../../../core/network/api_envelope.dart';
import '../../../../core/network/api_exception.dart';
import '../../../../core/network/api_paths.dart';
import '../../../../core/network/dio_mapper.dart';
import '../../domain/entities/available_voucher.dart';
import '../../domain/entities/voucher_quote.dart';

abstract interface class PromotionRemoteDataSource {
  Future<VoucherQuote> validateVoucher({
    required String accessToken,
    required String code,
    required VoucherService service,
    required int orderAmountVnd,
    int? deliveryFeeVnd,
    String? storeId,
  });

  Future<List<AvailableVoucher>> listAvailable({
    required String accessToken,
    VoucherService? service,
  });
}

class DioPromotionRemoteDataSource implements PromotionRemoteDataSource {
  DioPromotionRemoteDataSource({required this.dio});

  final Dio dio;

  @override
  Future<VoucherQuote> validateVoucher({
    required String accessToken,
    required String code,
    required VoucherService service,
    required int orderAmountVnd,
    int? deliveryFeeVnd,
    String? storeId,
  }) async {
    try {
      final response = await dio.post<Object?>(
        ApiPaths.promotionsValidate,
        data: {
          'voucherCode': code,
          'serviceType': service.wire,
          'orderAmount': orderAmountVnd,
          'deliveryFee': ?deliveryFeeVnd,
          'storeId': ?storeId,
        },
        options: Options(headers: {'Authorization': 'Bearer $accessToken'}),
      );
      return decodeVoucherQuote(response.data);
    } on DioException catch (error) {
      throw apiExceptionFromDio(error);
    }
  }

  @override
  Future<List<AvailableVoucher>> listAvailable({
    required String accessToken,
    VoucherService? service,
  }) async {
    try {
      final response = await dio.get<Object?>(
        ApiPaths.promotionsAvailable,
        queryParameters: {'serviceType': ?service?.wire},
        options: Options(headers: {'Authorization': 'Bearer $accessToken'}),
      );
      return decodeAvailableVouchers(readSuccessPayload(response.data));
    } on DioException catch (error) {
      throw apiExceptionFromDio(error);
    }
  }
}

List<AvailableVoucher> decodeAvailableVouchers(Object? data) {
  final out = <AvailableVoucher>[];
  if (data is! List) return out;
  for (final raw in data) {
    final item = asJsonMap(raw);
    if (item == null) continue;
    final code = item['code'];
    final name = item['name'];
    final value = item['discountValue'];
    final ends = DateTime.tryParse('${item['endsAt']}');
    final kind = switch (item['discountType']) {
      'FIXED_AMOUNT' => VoucherDiscountKind.fixedAmount,
      'PERCENTAGE' => VoucherDiscountKind.percentage,
      'DELIVERY_DISCOUNT' => VoucherDiscountKind.deliveryDiscount,
      _ => null,
    };
    if (code is! String ||
        name is! String ||
        value is! num ||
        ends == null ||
        kind == null) {
      continue;
    }
    final description = item['description'];
    final maxDiscount = item['maxDiscountVnd'];
    final minOrder = item['minOrderVnd'];
    final usesLeft = item['usesLeft'];
    out.add(
      AvailableVoucher(
        code: code,
        name: name,
        description: description is String ? description : '',
        service: switch (item['serviceType']) {
          'RIDE' => VoucherService.ride,
          'FOOD' => VoucherService.food,
          _ => null,
        },
        kind: kind,
        discountValue: value.toInt(),
        maxDiscountVnd: maxDiscount is num ? maxDiscount.toInt() : null,
        minOrderVnd: minOrder is num ? minOrder.toInt() : 0,
        endsAt: ends.toLocal(),
        usesLeft: usesLeft is num ? usesLeft.toInt() : 1,
      ),
    );
  }
  return out;
}

VoucherQuote decodeVoucherQuote(Object? body) {
  final data = requireSuccessData(body);
  final valid = data['valid'];
  final code = data['code'];
  final discount = data['discountAmount'];
  final finalAmount = data['finalAmount'];
  if (valid is! bool ||
      code is! String ||
      discount is! num ||
      finalAmount is! num) {
    throw const ApiException(
      statusCode: 200,
      message: 'Invalid response',
      errorCode: 'INVALID_RESPONSE',
    );
  }
  final campaign = asJsonMap(data['campaign']);
  final reason = data['reason'];
  final rejectCode = data['rejectCode'];
  final name = campaign?['name'];
  return VoucherQuote(
    valid: valid,
    code: code,
    discountVnd: discount.toInt(),
    finalAmountVnd: finalAmount.toInt(),
    reason: reason is String && reason.isNotEmpty ? reason : null,
    campaignName: name is String && name.isNotEmpty ? name : null,
    rejectCode: rejectCode is String && rejectCode.isNotEmpty
        ? rejectCode
        : null,
  );
}

/// Offline/mock voucher check: `DEALGO10` takes 10% (max 20.000đ).
class FakePromotionRemoteDataSource implements PromotionRemoteDataSource {
  FakePromotionRemoteDataSource({this.error, List<AvailableVoucher>? available})
    : available =
          available ??
          [
            AvailableVoucher(
              code: 'DEALGO10',
              name: 'DealGo -10%',
              description: 'Giảm 10% tối đa 20.000đ',
              service: null,
              kind: VoucherDiscountKind.percentage,
              discountValue: 10,
              maxDiscountVnd: 20000,
              minOrderVnd: 0,
              endsAt: DateTime(2030),
              usesLeft: 1,
            ),
          ];

  Object? error;
  List<AvailableVoucher> available;
  final calls = <String>[];

  @override
  Future<VoucherQuote> validateVoucher({
    required String accessToken,
    required String code,
    required VoucherService service,
    required int orderAmountVnd,
    int? deliveryFeeVnd,
    String? storeId,
  }) async {
    calls.add(code);
    final failure = error;
    if (failure != null) {
      throw failure;
    }
    final normalized = code.trim().toUpperCase();
    if (normalized != 'DEALGO10') {
      return VoucherQuote(
        valid: false,
        code: normalized,
        discountVnd: 0,
        finalAmountVnd: orderAmountVnd,
        reason: "Mã voucher '$normalized' không tồn tại.",
        rejectCode: 'VOUCHER_NOT_FOUND',
      );
    }
    final discount = (orderAmountVnd * 0.1).round().clamp(0, 20000);
    return VoucherQuote(
      valid: true,
      code: normalized,
      discountVnd: discount,
      finalAmountVnd: orderAmountVnd - discount,
      campaignName: 'DealGo -10%',
    );
  }

  @override
  Future<List<AvailableVoucher>> listAvailable({
    required String accessToken,
    VoucherService? service,
  }) async {
    final failure = error;
    if (failure != null) {
      throw failure;
    }
    return [
      for (final v in available)
        if (service == null || v.service == null || v.service == service) v,
    ];
  }
}
