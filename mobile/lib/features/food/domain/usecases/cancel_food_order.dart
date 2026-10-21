import '../entities/food_models.dart';
import '../repositories/food_repository.dart';

/// Customer cancels a food order (`POST /v1/food/orders/:id/cancel`).
class CancelFoodOrder {
  const CancelFoodOrder(this._repository);

  final FoodRepository _repository;

  Future<ClaimedFoodDelivery> call({
    required String accessToken,
    required String orderId,
  }) {
    return _repository.cancelOrder(accessToken: accessToken, orderId: orderId);
  }
}
