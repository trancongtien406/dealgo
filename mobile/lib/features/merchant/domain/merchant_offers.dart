import '../../food/domain/entities/food_models.dart' show StoreOfferKind;

/// Live offers a store may run at once (backend STORE_OFFER_ACTIVE_LIMIT).
const merchantOfferLiveLimit = 10;

/// Longest offer window the backend accepts (STORE_OFFER_MAX_DAYS).
const merchantOfferMaxDays = 180;

enum MerchantOfferStatus {
  active('ACTIVE'),
  paused('PAUSED'),
  ended('ENDED'),
  cancelled('CANCELLED'),
  draft('DRAFT');

  const MerchantOfferStatus(this.wire);

  final String wire;

  static MerchantOfferStatus parse(Object? raw) => values.firstWhere(
    (status) => status.wire == raw,
    orElse: () => MerchantOfferStatus.ended,
  );
}

/// A store-funded FOOD offer the merchant runs for its own store.
class MerchantOffer {
  const MerchantOffer({
    required this.id,
    required this.code,
    required this.name,
    required this.kind,
    required this.discountValue,
    required this.minOrderVnd,
    required this.usageLimit,
    required this.usedCount,
    required this.userLimit,
    required this.status,
    required this.startsAt,
    required this.endsAt,
    this.maxDiscountVnd,
  });

  final String id;
  final String code;
  final String name;
  final StoreOfferKind kind;

  /// VND for fixed amount, percent for percentage.
  final int discountValue;
  final int? maxDiscountVnd;
  final int minOrderVnd;
  final int usageLimit;
  final int usedCount;
  final int userLimit;
  final MerchantOfferStatus status;
  final DateTime startsAt;
  final DateTime endsAt;

  /// Still counts against [merchantOfferLiveLimit].
  bool isLive(DateTime now) =>
      (status == MerchantOfferStatus.active ||
          status == MerchantOfferStatus.paused) &&
      endsAt.isAfter(now);

  bool isUpcoming(DateTime now) =>
      status == MerchantOfferStatus.active && startsAt.isAfter(now);

  MerchantOffer withStatus(MerchantOfferStatus next) => MerchantOffer(
    id: id,
    code: code,
    name: name,
    kind: kind,
    discountValue: discountValue,
    maxDiscountVnd: maxDiscountVnd,
    minOrderVnd: minOrderVnd,
    usageLimit: usageLimit,
    usedCount: usedCount,
    userLimit: userLimit,
    status: next,
    startsAt: startsAt,
    endsAt: endsAt,
  );
}

class MerchantOfferDraft {
  const MerchantOfferDraft({
    required this.name,
    required this.kind,
    required this.discountValue,
    required this.minOrderVnd,
    required this.usageLimit,
    required this.userLimit,
    required this.startsAt,
    required this.endsAt,
    this.code,
    this.maxDiscountVnd,
  });

  final String name;

  /// Null = the backend generates one.
  final String? code;
  final StoreOfferKind kind;
  final int discountValue;
  final int? maxDiscountVnd;
  final int minOrderVnd;
  final int usageLimit;
  final int userLimit;
  final DateTime startsAt;
  final DateTime endsAt;

  Map<String, Object?> toJson() => {
    'name': name.trim(),
    if (code != null && code!.trim().isNotEmpty) 'code': code!.trim(),
    'discountType': kind == StoreOfferKind.percentage
        ? 'PERCENTAGE'
        : 'FIXED_AMOUNT',
    'discountValue': discountValue,
    if (kind == StoreOfferKind.percentage) 'maxDiscountAmount': maxDiscountVnd,
    'minOrderAmount': minOrderVnd,
    'usageLimit': usageLimit,
    'userLimit': userLimit,
    'startDate': startsAt.toUtc().toIso8601String(),
    'endDate': endsAt.toUtc().toIso8601String(),
  };
}

abstract interface class MerchantOfferRepository {
  Future<List<MerchantOffer>> list({required String accessToken});

  Future<MerchantOffer> create({
    required String accessToken,
    required MerchantOfferDraft draft,
  });

  /// [status] is active (resume), paused or ended.
  Future<MerchantOffer> setStatus({
    required String accessToken,
    required String offerId,
    required MerchantOfferStatus status,
  });
}
