import '../entities/food_models.dart';
import '../repositories/food_repository.dart';

class ListFoodStores {
  const ListFoodStores(this._repository);

  final FoodRepository _repository;

  Future<List<FoodStoreSummary>> call(
    String accessToken, {
    double? lat,
    double? lng,
  }) {
    return _repository.listStores(accessToken, lat: lat, lng: lng);
  }
}
