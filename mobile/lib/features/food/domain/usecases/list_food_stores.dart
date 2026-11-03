import '../entities/food_models.dart';
import '../repositories/food_repository.dart';

class ListFoodStores {
  const ListFoodStores(this._repository);

  final FoodRepository _repository;

  Future<FoodStorePageResult> call(
    String accessToken, {
    double? lat,
    double? lng,
    String? search,
    String? sortBy,
    int? maxKm,
    String? category,
    int page = 1,
    int limit = 20,
  }) {
    return _repository.listStores(
      accessToken,
      lat: lat,
      lng: lng,
      search: search,
      sortBy: sortBy,
      maxKm: maxKm,
      category: category,
      page: page,
      limit: limit,
    );
  }
}
