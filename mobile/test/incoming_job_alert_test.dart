import 'package:dealgo/features/driver/data/datasources/fake_driver_jobs_client.dart';
import 'package:dealgo/features/driver/data/repositories/driver_jobs_repository_impl.dart';
import 'package:dealgo/features/driver/domain/usecases/list_open_driver_rides.dart';
import 'package:dealgo/features/driver/domain/usecases/list_ready_driver_orders.dart';
import 'package:dealgo/features/driver/presentation/cubit/driver_feed_cubit.dart';
import 'package:dealgo/features/driver/presentation/widgets/incoming_job_alert.dart';
import 'package:dealgo/features/ride/domain/entities/ride_models.dart';
import 'package:dealgo/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';

class _Ringer implements IncomingJobRinger {
  int starts = 0;
  int stops = 0;
  bool get ringing => starts > stops;
  @override
  Future<void> start({required bool customSound}) async => starts++;
  @override
  Future<void> stop() async => stops++;
}

final _t0 = DateTime.utc(2026, 10, 29, 10);

OpenRide _ride(String id, {int expiresIn = 60}) => OpenRide(
  id: id,
  status: 'NEGOTIATING',
  pickup: const RidePoint(lat: 10.77, lng: 106.7, label: '12 Lê Lợi'),
  dropoff: const RidePoint(lat: 10.78, lng: 106.71, label: 'Chợ Bến Thành'),
  offeredFareVnd: 35000,
  referenceFareVnd: 35000,
  expiresAt: _t0.add(Duration(seconds: expiresIn)).toIso8601String(),
  offerCount: 0,
);

void main() {
  late FakeDriverJobsClient client;
  late DriverFeedCubit cubit;
  late _Ringer ringer;
  late DateTime now;

  setUp(() {
    IncomingJobAlertHost.enabled = true;
    client = FakeDriverJobsClient();
    final repo = DriverJobsRepositoryImpl(client);
    cubit = DriverFeedCubit(
      listOpenDriverRides: ListOpenDriverRides(repo),
      listReadyDriverOrders: ListReadyDriverOrders(repo),
    );
    ringer = _Ringer();
    now = _t0;
  });

  tearDown(() => cubit.close());

  Future<void> pump(WidgetTester tester) => tester.pumpWidget(
    BlocProvider.value(
      value: cubit,
      child: MaterialApp(
        locale: const Locale('vi'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: IncomingJobAlertHost(
          ringer: ringer,
          clock: () => now,
          inCall: () => false,
          pollEvery: const Duration(hours: 1),
          child: const Scaffold(body: Text('jobs')),
        ),
      ),
    ),
  );

  Future<void> feed(WidgetTester tester, List<OpenRide> rides) async {
    client.openRides = rides;
    await tester.runAsync(() => cubit.sync(online: true, accessToken: 't'));
    await tester.pump();
  }

  testWidgets('new job: full-screen card rings with countdown until skip', (
    tester,
  ) async {
    await pump(tester);
    await feed(tester, [_ride('r1', expiresIn: 90)]);
    expect(find.byKey(const Key('incoming-job-alert')), findsOneWidget);
    expect(find.text('1:30'), findsOneWidget);
    expect(ringer.ringing, isTrue);
    now = now.add(const Duration(seconds: 10));
    await tester.pump(const Duration(seconds: 1));
    expect(find.text('1:20'), findsOneWidget);
    expect(ringer.ringing, isTrue, reason: 'keeps ringing, not a brief beep');
    await tester.tap(find.byKey(const Key('incoming-job-skip')));
    await tester.pump();
    expect(find.byKey(const Key('incoming-job-alert')), findsNothing);
    expect(ringer.ringing, isFalse);
    // Same job on the next refresh does not ring again.
    await feed(tester, [_ride('r1', expiresIn: 90)]);
    expect(find.byKey(const Key('incoming-job-alert')), findsNothing);
  });

  testWidgets('job cancelled/taken (gone from feed) dismisses and stops', (
    tester,
  ) async {
    await pump(tester);
    await feed(tester, [_ride('r1')]);
    expect(ringer.ringing, isTrue);
    await feed(tester, []);
    expect(find.byKey(const Key('incoming-job-alert')), findsNothing);
    expect(ringer.ringing, isFalse);
  });

  testWidgets('expiry dismisses and moves to the next open job', (
    tester,
  ) async {
    await pump(tester);
    await feed(tester, [_ride('r1', expiresIn: 5), _ride('r2', expiresIn: 60)]);
    expect(find.text('0:05'), findsOneWidget);
    now = now.add(const Duration(seconds: 6));
    await tester.pump(const Duration(seconds: 1));
    expect(find.byKey(const Key('incoming-job-alert')), findsOneWidget);
    expect(find.text('0:54'), findsOneWidget);
    expect(ringer.ringing, isTrue);
  });
}
