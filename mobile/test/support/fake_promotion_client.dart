import 'package:dealgo/features/promotion/domain/entities/available_voucher.dart';
import 'package:dealgo/features/promotion/domain/entities/voucher_discount.dart';
import 'package:dealgo/features/promotion/domain/entities/voucher_quote.dart';
import 'package:dealgo/features/promotion/domain/repositories/promotion_repository.dart';

/// Promotion seam for widget tests: empty unless a test seeds vouchers.
class FakePromotionClient implements PromotionRepository {
  FakePromotionClient({List<AvailableVoucher>? available, this.error})
    : available = available ?? const [];

  final List<AvailableVoucher> available;

  /// Thrown by [listAvailable] when set (the discovery blocks must hide).
  Object? error;

  @override
  Future<List<AvailableVoucher>> listAvailable({
    required String accessToken,
    VoucherService? service,
    String? storeId,
  }) async {
    final failure = error;
    if (failure != null) {
      throw failure;
    }
    return [
      for (final voucher in available)
        if (service == null ||
            voucher.service == null ||
            voucher.service == service)
          voucher,
    ];
  }

  @override
  Future<VoucherQuote> validateVoucher({
    required String accessToken,
    required String code,
    required VoucherService service,
    required int orderAmountVnd,
    int? deliveryFeeVnd,
    String? storeId,
  }) async {
    final failure = error;
    if (failure != null) {
      throw failure;
    }
    final normalized = code.trim().toUpperCase();
    AvailableVoucher? voucher;
    for (final candidate in available) {
      if (candidate.code.toUpperCase() == normalized) {
        voucher = candidate;
        break;
      }
    }
    if (voucher == null) {
      return VoucherQuote(
        valid: false,
        code: normalized,
        discountVnd: 0,
        finalAmountVnd: orderAmountVnd,
        rejectCode: 'VOUCHER_NOT_FOUND',
      );
    }
    final rawDiscount = switch (voucher.kind) {
      VoucherDiscountKind.percentage => percentVoucherDiscountVnd(
        orderAmountVnd,
        voucher.discountValue,
        voucher.maxDiscountVnd,
      ),
      VoucherDiscountKind.fixedAmount ||
      VoucherDiscountKind.deliveryDiscount => voucher.discountValue,
    };
    final discount = rawDiscount.clamp(0, orderAmountVnd);
    return VoucherQuote(
      valid: true,
      code: normalized,
      discountVnd: discount,
      finalAmountVnd: orderAmountVnd - discount,
      campaignName: voucher.name,
    );
  }
}
