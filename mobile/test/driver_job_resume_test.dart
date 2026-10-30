import 'dart:async';

import 'package:dealgo/core/realtime/snapshot_realtime.dart';
import 'package:dealgo/features/driver/data/datasources/driver_active_job_client.dart';
import 'package:dealgo/features/driver/presentation/cubit/driver_duty_cubit.dart';
import 'package:dealgo/features/driver/presentation/utils/driver_job_resumer.dart';
import 'package:dealgo/features/driver/presentation/utils/driver_routes.dart';
import 'package:dealgo/features/identity/domain/entities/app_role.dart';
import 'package:fake_async/fake_async.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';

/// Driver relaunch: resume the in-progress job, stay online, keep reporting GPS.
void main() {
  test('parses the active-job payload', () {
    final ride = DriverActiveJob.fromData({
      'job': {'kind': 'RIDE', 'id': 'r1'},
    });
    expect(ride?.route, DriverRoutes.active('r1'));
    expect(
      DriverActiveJob.fromData({
        'job': {'kind': 'FOOD_ORDER', 'id': 'o1'},
      })?.isRide,
      isFalse,
    );
    expect(DriverActiveJob.fromData({'job': null}), isNull);
    expect(
      DriverActiveJob.fromData({
        'job': {'kind': 'BUS', 'id': 'x'},
      }),
      isNull,
    );
  });

  group('DriverJobResumer', () {
    late FakeDriverActiveJobSource source;
    late List<String> routes;
    late int onlineCalls;
    late DriverJobResumer resumer;

    setUp(() {
      source = FakeDriverActiveJobSource(
        const DriverActiveJob(kind: 'RIDE', id: 'r1'),
      );
      routes = [];
      onlineCalls = 0;
      resumer = DriverJobResumer(
        source: source,
        ensureOnline: () => onlineCalls++,
        navigate: routes.add,
      );
    });

    test(
      'ride in progress → online + active ride page, once per user',
      () async {
        await resumer.onSignedIn(
          userId: 'd1',
          roles: [AppRole.driver],
          profileDone: true,
        );
        await resumer.onSignedIn(
          userId: 'd1',
          roles: [AppRole.driver],
          profileDone: true,
        );
        expect(routes, [DriverRoutes.active('r1')]);
        expect(onlineCalls, 1);
        expect(source.calls, 1);
        resumer.reset(); // sign-out
        await resumer.onSignedIn(
          userId: 'd1',
          roles: [AppRole.driver],
          profileDone: true,
        );
        expect(source.calls, 2);
      },
    );

    test('food delivery → online + delivery page by id', () async {
      source.job = const DriverActiveJob(kind: 'FOOD_ORDER', id: 'o1');
      await resumer.onSignedIn(
        userId: 'd1',
        roles: [AppRole.customer, AppRole.driver],
        profileDone: true,
      );
      expect(routes, [DriverRoutes.food('o1')]);
      expect(onlineCalls, 1);
    });

    test('network failure retries with backoff in the session', () {
      fakeAsync((async) {
        source.failures = 2;
        resumer = DriverJobResumer(
          source: source,
          ensureOnline: () => onlineCalls++,
          navigate: routes.add,
          baseDelay: const Duration(seconds: 2),
        );
        resumer.onSignedIn(
          userId: 'd1',
          roles: [AppRole.driver],
          profileDone: true,
        );
        async.flushMicrotasks();
        expect(source.calls, 1);
        expect(resumer.retryScheduled, isTrue);
        async.elapse(const Duration(seconds: 2));
        expect(source.calls, 2);
        async.elapse(const Duration(seconds: 3));
        expect(source.calls, 2, reason: 'second wait is 4s');
        async.elapse(const Duration(seconds: 1));
        expect(source.calls, 3);
        expect(routes, [DriverRoutes.active('r1')]);
        expect(onlineCalls, 1);
      });
    });

    test('sign-out cancels a pending retry', () {
      fakeAsync((async) {
        source.failures = 1;
        resumer.onSignedIn(
          userId: 'd1',
          roles: [AppRole.driver],
          profileDone: true,
        );
        async.flushMicrotasks();
        resumer.reset();
        async.elapse(const Duration(minutes: 2));
        expect(source.calls, 1);
        expect(routes, isEmpty);
      });
    });

    test('idle, non-driver or profile not done → nothing', () async {
      source.job = null;
      await resumer.onSignedIn(
        userId: 'd1',
        roles: [AppRole.driver],
        profileDone: true,
      );
      await resumer.onSignedIn(
        userId: 'c1',
        roles: [AppRole.customer],
        profileDone: true,
      );
      await resumer.onSignedIn(
        userId: 'd2',
        roles: [AppRole.driver],
        profileDone: false,
      );
      expect(routes, isEmpty);
      expect(onlineCalls, 0);
      expect(source.calls, 1);
    });
  });

  testWidgets(
    'ensureDriverOnDuty puts an offline driver online (deep link entry)',
    (tester) async {
      final duty = DriverDutyCubit();
      addTearDown(duty.close);
      late BuildContext ctx;
      await tester.pumpWidget(
        BlocProvider.value(
          value: duty,
          child: Builder(
            builder: (context) {
              ctx = context;
              return const SizedBox();
            },
          ),
        ),
      );
      expect(duty.state, isFalse);
      ensureDriverOnDuty(ctx);
      await tester.pump();
      expect(duty.state, isTrue);
      ensureDriverOnDuty(ctx); // idempotent
      expect(duty.state, isTrue);
    },
  );
  test(
    'open app picks up a job ASSIGNED later on foreground recheck (no timer)',
    () {
      fakeAsync((async) {
        final source = FakeDriverActiveJobSource();
        final routes = <String>[];
        var location = '/driver/services';
        final resumer = DriverJobResumer(
          source: source,
          ensureOnline: () {},
          navigate: (r) {
            routes.add(r);
            location = r;
          },
          currentLocation: () => location,
        );
        resumer.onSignedIn(
          userId: 'd1',
          roles: [AppRole.driver],
          profileDone: true,
        );
        async.flushMicrotasks();
        expect(routes, isEmpty);

        source.job = const DriverActiveJob(kind: 'FOOD_ORDER', id: 'o9');
        async.elapse(const Duration(seconds: 60));
        expect(routes, isEmpty, reason: 't50u: no watch timer');
        unawaited(resumer.recheck());
        async.flushMicrotasks();
        expect(routes, [DriverRoutes.food('o9')]);

        // Already on a job screen: no re-navigation.
        async.elapse(const Duration(seconds: 60));
        expect(routes.length, 1);

        // Foreground recheck from home after the job page was left.
        location = '/driver/services';
        resumer.recheck();
        async.flushMicrotasks();
        expect(routes.length, 2);

        resumer.reset();
        final calls = source.calls;
        async.elapse(const Duration(seconds: 60));
        expect(source.calls, calls, reason: 'sign-out stops the watch');
      });
    },
  );
  test(
    'socket push: no polling; ASSIGNED hint or reconnect triggers one GET',
    () {
      fakeAsync((async) {
        final source = FakeDriverActiveJobSource();
        final hints = StreamController<SnapshotHint>.broadcast();
        final reconnects = StreamController<void>.broadcast();
        final routes = <String>[];
        var location = '/driver/services';
        final resumer = DriverJobResumer(
          source: source,
          ensureOnline: () {},
          navigate: (r) {
            routes.add(r);
            location = r;
          },
          currentLocation: () => location,
          jobHints: hints.stream,
          reconnects: reconnects.stream,
        );
        resumer.onSignedIn(
          userId: 'd1',
          roles: [AppRole.driver],
          profileDone: true,
        );
        async.flushMicrotasks();
        final afterOpen = source.calls;
        async.elapse(const Duration(minutes: 5));
        expect(source.calls, afterOpen, reason: 'no timer GETs');

        source.job = const DriverActiveJob(kind: 'RIDE', id: 'r7');
        hints.add(
          const SnapshotHint(
            aggregateType: 'Ride',
            aggregateId: 'r7',
            status: 'ASSIGNED',
            revision: 'x',
            occurredAt: 't',
          ),
        );
        async.flushMicrotasks();
        expect(routes, [DriverRoutes.active('r7')]);

        location = '/driver/services';
        reconnects.add(null);
        async.flushMicrotasks();
        expect(routes.length, 2);
        resumer.reset();
      });
    },
  );
}
