/// Trip transitions the assigned driver drives on the backend state machine.
enum RideDriverAction {
  /// ASSIGNED → DRIVER_EN_ROUTE
  enRoute('en-route'),

  /// DRIVER_EN_ROUTE → DRIVER_ARRIVED
  arrived('arrived'),

  /// DRIVER_ARRIVED → IN_TRIP
  start('start'),

  /// IN_TRIP → COMPLETED
  complete('complete');

  const RideDriverAction(this.pathSegment);

  final String pathSegment;
}
