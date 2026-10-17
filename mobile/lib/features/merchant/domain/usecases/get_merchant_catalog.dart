import '../../../food/domain/entities/food_models.dart';
import '../repositories/merchant_orders_repository.dart';

class GetMerchantCatalog {
  const GetMerchantCatalog(this._repository);

  final MerchantOrdersRepository _repository;

  Future<FoodStoreDetail> call(String accessToken) {
    return _repository.getMerchantCatalog(accessToken);
  }
}
