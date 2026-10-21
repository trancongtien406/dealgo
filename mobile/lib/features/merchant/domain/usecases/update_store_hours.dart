import '../../../food/domain/entities/food_models.dart';
import '../repositories/merchant_orders_repository.dart';

/// M023 — replace the store weekly hours / closed days / cut-off (DEC-PROD-027).
class UpdateStoreHours {
  const UpdateStoreHours(this._repository);

  final MerchantOrdersRepository _repository;

  Future<FoodStoreDetail> call({
    required String accessToken,
    required StoreSchedule schedule,
  }) {
    return _repository.updateStoreHours(
      accessToken: accessToken,
      schedule: schedule,
    );
  }
}
