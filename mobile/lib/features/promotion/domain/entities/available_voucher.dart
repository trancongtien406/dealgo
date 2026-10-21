import 'voucher_quote.dart';

enum VoucherDiscountKind { fixedAmount, percentage, deliveryDiscount }

/// A running campaign the customer can still use (`GET /v1/promotions/available`).
class AvailableVoucher {
  const AvailableVoucher({
    required this.code,
    required this.name,
    required this.description,
    required this.service,
    required this.kind,
    required this.discountValue,
    required this.minOrderVnd,
    required this.endsAt,
    required this.usesLeft,
    this.maxDiscountVnd,
  });

  final String code;
  final String name;
  final String description;

  /// null = every service.
  final VoucherService? service;
  final VoucherDiscountKind kind;
  final int discountValue;
  final int? maxDiscountVnd;
  final int minOrderVnd;
  final DateTime endsAt;
  final int usesLeft;
}
