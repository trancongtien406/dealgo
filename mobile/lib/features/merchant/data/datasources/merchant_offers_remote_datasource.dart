import 'package:dio/dio.dart';

import '../../../../core/network/api_envelope.dart';
import '../../../../core/network/api_exception.dart';
import '../../../../core/network/api_paths.dart';
import '../../../../core/network/dio_mapper.dart';
import '../../../food/domain/entities/food_models.dart' show StoreOfferKind;
import '../../domain/merchant_offers.dart';

class DioMerchantOfferRemoteDataSource implements MerchantOfferRepository {
  DioMerchantOfferRemoteDataSource({required this.dio});

  final Dio dio;

  Options _auth(String token) =>
      Options(headers: {'Authorization': 'Bearer $token'});

  @override
  Future<List<MerchantOffer>> list({required String accessToken}) async {
    try {
      final response = await dio.get<Object?>(
        ApiPaths.foodMerchantPromotions,
        options: _auth(accessToken),
      );
      final items = requireSuccessData(response.data)['items'];
      return [
        if (items is List)
          for (final raw in items) ?decodeMerchantOffer(raw),
      ];
    } on DioException catch (error) {
      throw apiExceptionFromDio(error);
    }
  }

  @override
  Future<MerchantOffer> create({
    required String accessToken,
    required MerchantOfferDraft draft,
  }) async {
    try {
      final response = await dio.post<Object?>(
        ApiPaths.foodMerchantPromotions,
        data: draft.toJson(),
        options: _auth(accessToken),
      );
      return _require(decodeMerchantOffer(readSuccessPayload(response.data)));
    } on DioException catch (error) {
      throw apiExceptionFromDio(error);
    }
  }

  @override
  Future<MerchantOffer> setStatus({
    required String accessToken,
    required String offerId,
    required MerchantOfferStatus status,
  }) async {
    try {
      final response = await dio.patch<Object?>(
        ApiPaths.foodMerchantPromotionStatus(offerId),
        data: {'status': status.wire},
        options: _auth(accessToken),
      );
      return _require(decodeMerchantOffer(readSuccessPayload(response.data)));
    } on DioException catch (error) {
      throw apiExceptionFromDio(error);
    }
  }

  MerchantOffer _require(MerchantOffer? offer) {
    if (offer == null) {
      throw const ApiException(
        statusCode: 200,
        message: 'Invalid response',
        errorCode: 'INVALID_RESPONSE',
      );
    }
    return offer;
  }
}

int? _int(Object? value) => value is num ? value.toInt() : null;

/// Decodes a PromotionCampaign row; null when a required field is missing.
MerchantOffer? decodeMerchantOffer(Object? raw) {
  final map = asJsonMap(raw);
  if (map == null) return null;
  final id = map['id'];
  final code = map['code'];
  final name = map['name'];
  final value = _int(map['discountValue']);
  final starts = DateTime.tryParse('${map['startDate']}');
  final ends = DateTime.tryParse('${map['endDate']}');
  if (id is! String ||
      code is! String ||
      name is! String ||
      value == null ||
      starts == null ||
      ends == null) {
    return null;
  }
  return MerchantOffer(
    id: id,
    code: code,
    name: name,
    kind: map['discountType'] == 'PERCENTAGE'
        ? StoreOfferKind.percentage
        : StoreOfferKind.fixedAmount,
    discountValue: value,
    maxDiscountVnd: _int(map['maxDiscountAmount']),
    minOrderVnd: _int(map['minOrderAmount']) ?? 0,
    usageLimit: _int(map['usageLimit']) ?? 0,
    usedCount: _int(map['usedCount']) ?? 0,
    userLimit: _int(map['userLimit']) ?? 1,
    status: MerchantOfferStatus.parse(map['status']),
    startsAt: starts.toLocal(),
    endsAt: ends.toLocal(),
  );
}

/// In-memory offers for tests and mock mode; mirrors the backend rules that
/// the UI relies on (live limit, closed offers stay closed).
class FakeMerchantOfferRepository implements MerchantOfferRepository {
  FakeMerchantOfferRepository({List<MerchantOffer>? seed})
    : offers = [...?seed];

  /// Two running offers for mock mode and screenshots.
  factory FakeMerchantOfferRepository.sample({DateTime? now}) {
    final at = now ?? DateTime.now();
    return FakeMerchantOfferRepository(
      seed: [
        MerchantOffer(
          id: 'offer-1',
          code: 'BUNBO20',
          name: 'Giảm 20% món bún',
          kind: StoreOfferKind.percentage,
          discountValue: 20,
          maxDiscountVnd: 30000,
          minOrderVnd: 80000,
          usageLimit: 200,
          usedCount: 46,
          userLimit: 2,
          status: MerchantOfferStatus.active,
          startsAt: at.subtract(const Duration(days: 3)),
          endsAt: at.add(const Duration(days: 11)),
        ),
        MerchantOffer(
          id: 'offer-2',
          code: 'FREESHIP15',
          name: 'Giảm 15K cho đơn từ 120K',
          kind: StoreOfferKind.fixedAmount,
          discountValue: 15000,
          minOrderVnd: 120000,
          usageLimit: 100,
          usedCount: 100,
          userLimit: 1,
          status: MerchantOfferStatus.paused,
          startsAt: at.subtract(const Duration(days: 10)),
          endsAt: at.add(const Duration(days: 4)),
        ),
      ],
    );
  }

  final List<MerchantOffer> offers;
  final List<MerchantOfferDraft> created = [];
  final List<({String id, MerchantOfferStatus status})> statusCalls = [];
  Object? listError;
  Object? createError;
  var _seq = 0;

  @override
  Future<List<MerchantOffer>> list({required String accessToken}) async {
    if (listError case final error?) throw error;
    return List.unmodifiable(offers);
  }

  @override
  Future<MerchantOffer> create({
    required String accessToken,
    required MerchantOfferDraft draft,
  }) async {
    if (createError case final error?) throw error;
    final now = DateTime.now();
    if (offers.where((o) => o.isLive(now)).length >= merchantOfferLiveLimit) {
      throw const ApiException(
        statusCode: 400,
        message: 'Mỗi cửa hàng chạy tối đa 10 ưu đãi cùng lúc.',
        errorCode: 'PROMOTION_STORE_LIMIT',
      );
    }
    created.add(draft);
    final offer = MerchantOffer(
      id: 'offer-new-${++_seq}',
      code: (draft.code?.trim().isNotEmpty ?? false)
          ? draft.code!.trim().toUpperCase()
          : 'DG${1000 + _seq}',
      name: draft.name.trim(),
      kind: draft.kind,
      discountValue: draft.discountValue,
      maxDiscountVnd: draft.maxDiscountVnd,
      minOrderVnd: draft.minOrderVnd,
      usageLimit: draft.usageLimit,
      usedCount: 0,
      userLimit: draft.userLimit,
      status: MerchantOfferStatus.active,
      startsAt: draft.startsAt,
      endsAt: draft.endsAt,
    );
    offers.insert(0, offer);
    return offer;
  }

  @override
  Future<MerchantOffer> setStatus({
    required String accessToken,
    required String offerId,
    required MerchantOfferStatus status,
  }) async {
    statusCalls.add((id: offerId, status: status));
    final index = offers.indexWhere((o) => o.id == offerId);
    if (index < 0) {
      throw const ApiException(
        statusCode: 404,
        message: 'Không tìm thấy ưu đãi.',
        errorCode: 'PROMOTION_NOT_FOUND',
      );
    }
    final updated = offers[index].withStatus(status);
    offers[index] = updated;
    return updated;
  }
}
