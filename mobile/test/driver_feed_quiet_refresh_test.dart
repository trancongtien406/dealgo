import 'package:dealgo/core/network/api_exception.dart';
import 'package:dealgo/core/realtime/fake_snapshot_realtime.dart';
import 'package:dealgo/features/driver/data/datasources/fake_driver_jobs_client.dart';
import 'package:dealgo/features/driver/data/repositories/driver_jobs_repository_impl.dart';
import 'package:dealgo/features/driver/domain/usecases/list_open_driver_rides.dart';
import 'package:dealgo/features/driver/domain/usecases/list_ready_driver_orders.dart';
import 'package:dealgo/features/driver/presentation/cubit/driver_feed_cubit.dart';
import 'package:flutter_test/flutter_test.dart';

DriverFeedCubit _cubit(FakeDriverJobsClient client) {
  final repo = DriverJobsRepositoryImpl(client);
  return DriverFeedCubit(
    listOpenDriverRides: ListOpenDriverRides(repo),
    listReadyDriverOrders: ListReadyDriverOrders(repo),
  );
}

void main() {
  test(
    'a quiet refresh (new-job hint) never flashes the loading state',
    () async {
      final client = FakeDriverJobsClient();
      final cubit = _cubit(client);
      await cubit.sync(online: true, accessToken: 't');
      expect(cubit.state, isA<DriverFeedReady>());
      final seen = <DriverFeedState>[];
      final sub = cubit.stream.listen(seen.add);
      await cubit.sync(online: true, accessToken: 't', quiet: true);
      await Future<void>.delayed(Duration.zero);
      expect(seen.whereType<DriverFeedLoading>(), isEmpty);
      expect(cubit.state, isA<DriverFeedReady>());
      expect(client.openCalls.length, 2);
      await sub.cancel();
      await cubit.close();
    },
  );

  test('a failed quiet refresh keeps the list already on screen', () async {
    final client = FakeDriverJobsClient();
    final cubit = _cubit(client);
    await cubit.sync(online: true, accessToken: 't');
    client.openError = const ApiException(
      statusCode: 500,
      message: 'x',
      errorCode: 'INTERNAL',
    );
    await cubit.sync(online: true, accessToken: 't', quiet: true);
    expect(cubit.state, isA<DriverFeedReady>());
    await cubit.close();
  });

  test('fake realtime exposes job request hints', () async {
    final realtime = FakeSnapshotRealtime();
    final got = <void>[];
    final sub = realtime.jobRequests.listen(got.add);
    realtime.emitJobRequest();
    await Future<void>.delayed(Duration.zero);
    expect(got.length, 1);
    await sub.cancel();
  });
}
