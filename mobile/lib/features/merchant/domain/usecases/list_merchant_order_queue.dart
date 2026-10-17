import '../../../food/domain/entities/food_models.dart';
import '../repositories/merchant_orders_repository.dart';

class ListMerchantOrderQueue {
  const ListMerchantOrderQueue(this._repository);

  final MerchantOrdersRepository _repository;

  Future<List<MerchantQueueOrder>> call(String accessToken) {
    return _repository.listOrderQueue(accessToken);
  }
}
