enum DriverTopUpStatus {
  pending('PENDING'),
  paid('PAID'),
  expired('EXPIRED'),
  cancelled('CANCELLED'),
  refundPending('REFUND_PENDING'),
  refunded('REFUNDED'),
  failed('FAILED');

  const DriverTopUpStatus(this.wire);

  final String wire;

  static DriverTopUpStatus fromWire(Object? raw) => values.firstWhere(
    (status) => status.wire == raw,
    orElse: () => DriverTopUpStatus.failed,
  );

  bool get isOpen => this == DriverTopUpStatus.pending;
}

class DriverTopUp {
  const DriverTopUp({
    required this.id,
    required this.amountVnd,
    required this.status,
    required this.createdAt,
    this.remainingVnd = 0,
    this.consumedVnd = 0,
    this.refundedVnd = 0,
    this.orderCode = 0,
    this.provider = 'payos',
    this.checkoutUrl,
    this.qrCode,
    this.expiresAt,
    this.paidAt,
  });

  final String id;
  final int amountVnd;

  /// Money from this top-up still available to offset fees.
  final int remainingVnd;

  /// Money already applied to platform fee settlements.
  final int consumedVnd;

  /// Money already returned by Ops (manual bank transfer).
  final int refundedVnd;

  /// Order code sent to the PSP; what the driver quotes to support.
  final int orderCode;
  final String provider;
  final DriverTopUpStatus status;
  final String? checkoutUrl;
  final String? qrCode;
  final DateTime? expiresAt;
  final DateTime? paidAt;
  final DateTime createdAt;

  bool get isPayable =>
      status.isOpen &&
      (expiresAt == null || expiresAt!.isAfter(DateTime.now()));

  DriverTopUp copyWith({
    DriverTopUpStatus? status,
    int? remainingVnd,
    int? consumedVnd,
    int? refundedVnd,
    DateTime? paidAt,
  }) {
    return DriverTopUp(
      id: id,
      amountVnd: amountVnd,
      status: status ?? this.status,
      createdAt: createdAt,
      remainingVnd: remainingVnd ?? this.remainingVnd,
      consumedVnd: consumedVnd ?? this.consumedVnd,
      refundedVnd: refundedVnd ?? this.refundedVnd,
      orderCode: orderCode,
      provider: provider,
      checkoutUrl: checkoutUrl,
      qrCode: qrCode,
      expiresAt: expiresAt,
      paidAt: paidAt ?? this.paidAt,
    );
  }
}

/// Driver prepaid balance (DEC-PROD-093). Credit can only offset platform fees:
/// it is never withdrawable and never transferable.
class DriverCredit {
  const DriverCredit({
    required this.creditVnd,
    required this.owesVnd,
    required this.limitVnd,
    required this.blocked,
    required this.enabled,
    required this.minVnd,
    required this.maxVnd,
    required this.dailyLimitVnd,
    required this.maxCreditVnd,
    this.pendingTopUp,
    this.recentTopUps = const [],
  });

  /// Unused prepayment currently covering future fees.
  final int creditVnd;

  /// Fee debt still owed to DealGo after applying credit.
  final int owesVnd;

  /// Debt above which dispatch is blocked.
  final int limitVnd;
  final bool blocked;

  /// Top-up is switched on by Ops once the merchant account is live.
  final bool enabled;
  final int minVnd;
  final int maxVnd;
  final int dailyLimitVnd;
  final int maxCreditVnd;
  final DriverTopUp? pendingTopUp;
  final List<DriverTopUp> recentTopUps;
}

abstract interface class DriverCreditRepository {
  Future<DriverCredit> summary({required String accessToken});

  Future<DriverTopUp> createTopUp({
    required String accessToken,
    required int amountVnd,
    String? idempotencyKey,
  });

  Future<DriverTopUp> topUp({required String accessToken, required String id});

  Future<DriverTopUp> cancelTopUp({
    required String accessToken,
    required String id,
  });
}
