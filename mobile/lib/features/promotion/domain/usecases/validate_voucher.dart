import '../entities/voucher_quote.dart';
import '../repositories/promotion_repository.dart';

class ValidateVoucher {
  const ValidateVoucher(this._repository);

  final PromotionRepository _repository;

  Future<VoucherQuote> call({
    required String accessToken,
    required String code,
    required VoucherService service,
    required int orderAmountVnd,
    int? deliveryFeeVnd,
    String? storeId,
  }) {
    return _repository.validateVoucher(
      accessToken: accessToken,
      code: code,
      service: service,
      orderAmountVnd: orderAmountVnd,
      deliveryFeeVnd: deliveryFeeVnd,
      storeId: storeId,
    );
  }
}
