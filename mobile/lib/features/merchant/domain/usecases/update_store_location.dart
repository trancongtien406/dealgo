import '../../../food/domain/entities/food_models.dart';
import '../repositories/merchant_orders_repository.dart';

/// M030 — set the store pickup point drivers navigate to (DEC-PROD-044).
class UpdateStoreLocation {
  const UpdateStoreLocation(this._repository);

  final MerchantOrdersRepository _repository;

  Future<FoodStoreDetail> call({
    required String accessToken,
    required double lat,
    required double lng,
    String? addressLabel,
  }) {
    return _repository.updateStoreLocation(
      accessToken: accessToken,
      lat: lat,
      lng: lng,
      addressLabel: addressLabel,
    );
  }
}
