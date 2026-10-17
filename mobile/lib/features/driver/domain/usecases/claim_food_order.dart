import '../../../food/domain/entities/food_models.dart';
import '../params/claim_food_order_params.dart';
import '../repositories/driver_jobs_repository.dart';

class ClaimFoodOrder {
  const ClaimFoodOrder(this._repository);

  final DriverJobsRepository _repository;

  Future<ClaimedFoodDelivery> call(ClaimFoodOrderParams params) {
    return _repository.claimOrder(
      accessToken: params.accessToken,
      orderId: params.orderId,
    );
  }
}
