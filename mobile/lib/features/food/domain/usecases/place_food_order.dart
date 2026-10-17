import '../entities/food_models.dart';
import '../params/place_food_order_params.dart';
import '../repositories/food_repository.dart';

class PlaceFoodOrder {
  const PlaceFoodOrder(this._repository);

  final FoodRepository _repository;

  Future<PlacedFoodOrder> call(PlaceFoodOrderParams params) {
    return _repository.placeOrder(params);
  }
}
