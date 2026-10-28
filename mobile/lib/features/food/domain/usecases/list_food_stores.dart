import '../entities/food_models.dart';
import '../repositories/food_repository.dart';

class ListFoodStores {
  const ListFoodStores(this._repository);

  final FoodRepository _repository;

  Future<List<FoodStoreSummary>> call(
    String accessToken, {
    double? lat,
    double? lng,
    String? search,
  }) {
    return _repository.listStores(
      accessToken,
      lat: lat,
      lng: lng,
      search: search,
    );
  }
}
