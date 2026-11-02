import 'package:dealgo/core/realtime/fake_snapshot_realtime.dart';
import 'package:dealgo/features/ride/domain/repositories/ride_repository.dart';
import 'package:dealgo/features/ride/domain/usecases/get_ride.dart';
import 'package:dealgo/features/ride/presentation/cubit/ride_tracking_cubit.dart';
import 'package:flutter_test/flutter_test.dart';

class _UnusedRepository implements RideRepository {
  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError('${invocation.memberName}');
}

void main() {
  // Sentry FLUTTER-P: "Cannot emit new states after calling close" when a
  // realtime invalidation triggers refresh() after the tracking page closed.
  test('refresh after close is a no-op', () async {
    final cubit = RideTrackingCubit(
      getRide: GetRide(_UnusedRepository()),
      realtime: FakeSnapshotRealtime(),
    );
    await cubit.start(rideId: 'ride-1', accessToken: null);
    await cubit.close();
    await expectLater(cubit.refresh(), completes);
  });
}
