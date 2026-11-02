import '../../../active_job/domain/active_job_snapshot.dart';
import '../../domain/entities/ride_models.dart';
import '../../domain/entities/ride_money.dart';

ActiveJobSnapshot rideOfflineSnapshot(RideView ride) {
  final agreed = ride.agreedFareVnd;
  return ActiveJobSnapshot(
    kind: ActiveJobKind.ride,
    id: ride.id,
    status: ride.status.wire,
    savedAt: DateTime.now(),
    pickupLabel: ride.pickup.label,
    dropoffLabel: ride.dropoff.label,
    stopLabels: [for (final stop in ride.stops) stop.point.label],
    amountVnd: agreed,
    cashDueVnd: agreed != null && ride.discountVnd > 0
        ? rideCashAfterVoucher(agreed + ride.waitFeeVnd, ride.discountVnd)
        : null,
    code: ride.pickupCode,
  );
}
