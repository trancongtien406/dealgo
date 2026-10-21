/// Delivery transitions the assigned driver drives on a food order.
enum FoodDeliveryAction {
  /// ASSIGNED → PICKED_UP
  pickup('pickup'),

  /// PICKED_UP → DELIVERED
  deliver('deliver'),

  /// ASSIGNED | PICKED_UP → FAILED
  fail('fail');

  const FoodDeliveryAction(this.pathSegment);

  final String pathSegment;
}
