import '../../../food/domain/entities/food_models.dart';
import '../params/merchant_order_action_params.dart';
import '../repositories/merchant_orders_repository.dart';

class GetMerchantOrder {
  const GetMerchantOrder(this._repository);

  final MerchantOrdersRepository _repository;

  Future<FoodOrderDetail> call(MerchantOrderActionParams params) {
    return _repository.getOrder(
      accessToken: params.accessToken,
      orderId: params.orderId,
    );
  }
}
