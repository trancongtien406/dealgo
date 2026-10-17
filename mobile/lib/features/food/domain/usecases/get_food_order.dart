import '../entities/food_models.dart';
import '../params/get_food_order_params.dart';
import '../repositories/food_repository.dart';

class GetFoodOrder {
  const GetFoodOrder(this._repository);

  final FoodRepository _repository;

  Future<FoodOrderDetail> call(GetFoodOrderParams params) {
    return _repository.getOrder(
      accessToken: params.accessToken,
      orderId: params.orderId,
    );
  }
}
