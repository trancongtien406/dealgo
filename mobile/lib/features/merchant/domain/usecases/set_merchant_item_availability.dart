import '../../../food/domain/entities/food_models.dart';
import '../params/set_merchant_item_availability_params.dart';
import '../repositories/merchant_orders_repository.dart';

class SetMerchantItemAvailability {
  const SetMerchantItemAvailability(this._repository);

  final MerchantOrdersRepository _repository;

  Future<FoodMenuItem> call(SetMerchantItemAvailabilityParams params) {
    return _repository.setItemAvailability(
      accessToken: params.accessToken,
      itemId: params.itemId,
      available: params.available,
    );
  }
}
