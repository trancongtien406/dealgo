import '../../domain/entities/available_voucher.dart';
import '../../domain/entities/voucher_quote.dart';
import '../../domain/repositories/promotion_repository.dart';
import '../datasources/promotion_remote_datasource.dart';

class PromotionRepositoryImpl implements PromotionRepository {
  PromotionRepositoryImpl(this._remote);

  final PromotionRemoteDataSource _remote;

  @override
  Future<VoucherQuote> validateVoucher({
    required String accessToken,
    required String code,
    required VoucherService service,
    required int orderAmountVnd,
    int? deliveryFeeVnd,
    String? storeId,
  }) {
    return _remote.validateVoucher(
      accessToken: accessToken,
      code: code,
      service: service,
      orderAmountVnd: orderAmountVnd,
      deliveryFeeVnd: deliveryFeeVnd,
      storeId: storeId,
    );
  }

  @override
  Future<List<AvailableVoucher>> listAvailable({
    required String accessToken,
    VoucherService? service,
    String? storeId,
  }) => _remote.listAvailable(
    accessToken: accessToken,
    service: service,
    storeId: storeId,
  );
}
