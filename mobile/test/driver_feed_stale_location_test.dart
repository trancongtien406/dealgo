import 'package:dealgo/core/network/api_exception.dart';
import 'package:dealgo/features/driver/data/datasources/fake_driver_jobs_client.dart';
import 'package:dealgo/features/driver/data/repositories/driver_jobs_repository_impl.dart';
import 'package:dealgo/features/driver/domain/usecases/list_open_driver_rides.dart';
import 'package:dealgo/features/driver/domain/usecases/list_ready_driver_orders.dart';
import 'package:dealgo/features/driver/presentation/cubit/driver_feed_cubit.dart';
import 'package:flutter_test/flutter_test.dart';

const _stale = ApiException(
  statusCode: 409,
  message: 'Go online and share your current location to see nearby requests',
  errorCode: 'DRIVER_LOCATION_STALE',
);

DriverFeedCubit _cubit(FakeDriverJobsClient client) {
  final repo = DriverJobsRepositoryImpl(client);
  return DriverFeedCubit(
    listOpenDriverRides: ListOpenDriverRides(repo),
    listReadyDriverOrders: ListReadyDriverOrders(repo),
    staleLocationRetries: const [
      Duration(milliseconds: 5),
      Duration(milliseconds: 5),
    ],
  );
}

void main() {
  test(
    'opening from a push before the first fix waits for it instead of erroring',
    () async {
      final client = FakeDriverJobsClient(
        openError: _stale,
        readyError: _stale,
      );
      final cubit = _cubit(client);
      final done = cubit.sync(online: true, accessToken: 't');
      // The location reporter's first fix lands while the feed waits.
      await Future<void>.delayed(const Duration(milliseconds: 1));
      client
        ..openError = null
        ..readyError = null;
      await done;
      expect(cubit.state, isA<DriverFeedReady>());
      expect(client.openCalls.length, 2);
      await cubit.close();
    },
  );

  test('still reports the stale location after the retries run out', () async {
    final client = FakeDriverJobsClient(openError: _stale);
    final cubit = _cubit(client);
    await cubit.sync(online: true, accessToken: 't');
    expect(cubit.state, isA<DriverFeedFailed>());
    expect(client.openCalls.length, 3);
    await cubit.close();
  });

  test('other failures do not retry', () async {
    final client = FakeDriverJobsClient(
      openError: const ApiException(
        statusCode: 500,
        message: 'x',
        errorCode: 'INTERNAL',
      ),
    );
    final cubit = _cubit(client);
    await cubit.sync(online: true, accessToken: 't');
    expect(cubit.state, isA<DriverFeedFailed>());
    expect(client.openCalls.length, 1);
    await cubit.close();
  });
}
