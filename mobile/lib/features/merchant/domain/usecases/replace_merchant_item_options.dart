import '../../../food/domain/entities/food_models.dart';
import '../repositories/merchant_orders_repository.dart';

/// DEC-PROD-033 — saves the full option layout of one dish (server validates).
class ReplaceMerchantItemOptions {
  const ReplaceMerchantItemOptions(this._repository);

  final MerchantOrdersRepository _repository;

  Future<FoodMenuItem> call({
    required String accessToken,
    required String itemId,
    required List<FoodOptionGroup> groups,
  }) {
    return _repository.replaceItemOptions(
      accessToken: accessToken,
      itemId: itemId,
      groups: groups,
    );
  }
}
