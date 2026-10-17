import '../entities/food_models.dart';
import '../repositories/food_repository.dart';

class ListReadyFoodOrders {
  const ListReadyFoodOrders(this._repository);

  final FoodRepository _repository;

  Future<List<ReadyFoodJob>> call(String accessToken) {
    return _repository.listReadyOrders(accessToken);
  }
}
