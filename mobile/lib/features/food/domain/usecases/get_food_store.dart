import '../entities/food_models.dart';
import '../params/get_food_store_params.dart';
import '../repositories/food_repository.dart';

class GetFoodStore {
  const GetFoodStore(this._repository);

  final FoodRepository _repository;

  Future<FoodStoreDetail> call(GetFoodStoreParams params) {
    return _repository.getStore(params.accessToken, params.storeId);
  }
}
