import '../entities/available_voucher.dart';
import '../entities/voucher_quote.dart';

abstract interface class PromotionRepository {
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
