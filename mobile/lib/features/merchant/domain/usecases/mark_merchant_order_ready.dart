import '../../../food/domain/entities/food_models.dart';
import '../params/merchant_order_action_params.dart';
import '../repositories/merchant_orders_repository.dart';

class MarkMerchantOrderReady {
  const MarkMerchantOrderReady(this._repository);

  final MerchantOrdersRepository _repository;

  Future<MerchantOrderUpdate> call(MerchantOrderActionParams params) {
    return _repository.markOrderReady(
      accessToken: params.accessToken,
      orderId: params.orderId,
    );
  }
}
