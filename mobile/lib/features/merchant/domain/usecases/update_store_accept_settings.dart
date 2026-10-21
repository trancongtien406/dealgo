import '../../../food/domain/entities/food_models.dart';
import '../repositories/merchant_orders_repository.dart';

/// M022 — persist manual/auto accept, kitchen cap and default prep time (DEC-PROD-028).
class UpdateStoreAcceptSettings {
  const UpdateStoreAcceptSettings(this._repository);

  final MerchantOrdersRepository _repository;

  Future<FoodStoreDetail> call({
    required String accessToken,
    required StoreAcceptSettings settings,
    required int lastOrderMinutes,
  }) {
    return _repository.updateStoreAcceptSettings(
      accessToken: accessToken,
      settings: settings,
      lastOrderMinutes: lastOrderMinutes,
    );
  }
}
