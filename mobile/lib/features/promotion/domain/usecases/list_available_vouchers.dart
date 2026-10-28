import '../entities/available_voucher.dart';
import '../entities/voucher_quote.dart';
import '../repositories/promotion_repository.dart';

class ListAvailableVouchers {
  const ListAvailableVouchers(this._repository);

  final PromotionRepository _repository;

  Future<List<AvailableVoucher>> call({
    required String accessToken,
    VoucherService? service,
    String? storeId,
  }) => _repository.listAvailable(
    accessToken: accessToken,
    service: service,
    storeId: storeId,
  );
}
