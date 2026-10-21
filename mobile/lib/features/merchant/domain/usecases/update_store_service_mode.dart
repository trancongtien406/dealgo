import '../../../food/domain/entities/food_models.dart';
import '../repositories/merchant_orders_repository.dart';

/// M024 — persist the store intake mode (DEC-PROD-026).
class UpdateStoreServiceMode {
  const UpdateStoreServiceMode(this._repository);

  final MerchantOrdersRepository _repository;

  Future<FoodStoreDetail> call({
    required String accessToken,
    required StoreServiceMode mode,
    int? resumeAfterMinutes,
    int? busyExtraMinutes,
  }) {
    return _repository.updateStoreServiceMode(
      accessToken: accessToken,
      mode: mode,
      resumeAfterMinutes: resumeAfterMinutes,
      busyExtraMinutes: busyExtraMinutes,
    );
  }
}
