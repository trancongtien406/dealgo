import '../../../food/domain/params/food_delivery_action.dart';
import '../../../food/domain/entities/food_models.dart';
import '../repositories/driver_jobs_repository.dart';

/// Moves a claimed food order along pickup → deliver (or fail).
class AdvanceFoodDelivery {
  const AdvanceFoodDelivery(this._repository);

  final DriverJobsRepository _repository;

  Future<ClaimedFoodDelivery> call({
    required String accessToken,
    required String orderId,
    required FoodDeliveryAction action,

    /// DEC-PROD-036: handover code (pickup) or delivery code (deliver).
    String? code,

    /// Why the delivery failed (FOOD_FAIL_REASONS) and the note for OTHER.
    String? failReason,
    String? failNote,
  }) {
    return _repository.advanceDelivery(
      accessToken: accessToken,
      orderId: orderId,
      action: action,
      code: code,
      failReason: failReason,
      failNote: failNote,
    );
  }
}
