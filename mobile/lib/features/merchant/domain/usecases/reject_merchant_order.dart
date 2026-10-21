import '../../../food/domain/entities/food_models.dart';
import '../params/merchant_order_action_params.dart';
import '../repositories/merchant_orders_repository.dart';

/// Store declines a new (PLACED) order; the backend cancels it.
class RejectMerchantOrder {
  const RejectMerchantOrder(this._repository);

  final MerchantOrdersRepository _repository;

  Future<MerchantOrderUpdate> call(
    MerchantOrderActionParams params, {
    required FoodRejectReason reason,
    String? note,
  }) {
    return _repository.rejectOrder(
      accessToken: params.accessToken,
      orderId: params.orderId,
      reason: reason,
      note: note,
    );
  }
}
