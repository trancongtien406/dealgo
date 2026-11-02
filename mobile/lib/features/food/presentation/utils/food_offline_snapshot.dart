import '../../../active_job/domain/active_job_snapshot.dart';
import '../../domain/entities/food_models.dart';

ActiveJobSnapshot foodOfflineSnapshot(FoodOrderDetail order) =>
    ActiveJobSnapshot(
      kind: ActiveJobKind.foodOrder,
      id: order.id,
      status: order.status,
      savedAt: DateTime.now(),
      storeName: order.storeName,
      pickupLabel: order.pickup?.label,
      dropoffLabel: order.dropoff.label,
      amountVnd: order.totalVnd,
      code: order.deliveryCode,
    );

bool foodOrderEnded(FoodOrderDetail order) => switch (order.stage) {
  FoodTrackingStage.delivered ||
  FoodTrackingStage.failed ||
  FoodTrackingStage.cancelled => true,
  FoodTrackingStage.preparing ||
  FoodTrackingStage.onTheWay ||
  FoodTrackingStage.unknown => false,
};
