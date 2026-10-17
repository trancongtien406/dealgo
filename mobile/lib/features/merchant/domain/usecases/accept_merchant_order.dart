import '../../../food/domain/entities/food_models.dart';
import '../params/merchant_order_action_params.dart';
import '../repositories/merchant_orders_repository.dart';

class AcceptMerchantOrder {
  const AcceptMerchantOrder(this._repository);

  final MerchantOrdersRepository _repository;

  Future<MerchantOrderUpdate> call(MerchantOrderActionParams params) {
    return _repository.acceptOrder(
      accessToken: params.accessToken,
      orderId: params.orderId,
    );
  }
}
