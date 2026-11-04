import 'dart:io';

import 'package:dealgo/core/media/alert_audio.dart';
import 'package:dealgo/core/push/new_job_alert.dart';
import 'package:dealgo/core/realtime/fake_snapshot_realtime.dart';
import 'package:dealgo/features/food/domain/entities/food_models.dart';
import 'package:dealgo/features/merchant/domain/repositories/merchant_orders_repository.dart';
import 'package:dealgo/features/merchant/domain/usecases/list_merchant_order_queue.dart';
import 'package:dealgo/features/merchant/presentation/cubit/merchant_queue_cubit.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _Player implements NewJobAlertPlayer {
  final played = <String>[];
  var vibrations = 0;
  @override
  Future<void> playAsset(String asset) async => played.add(asset);
  @override
  Future<void> playDefault() async => played.add('default');
  @override
  Future<void> vibrate() async => vibrations++;
}

class _Clock {
  var now = DateTime.utc(2026, 10, 26, 16);
  DateTime call() => now;
  void advance(Duration d) => now = now.add(d);
}

MerchantQueueOrder _order(String id, String status) => MerchantQueueOrder(
  id: id,
  storeId: 'store-1',
  status: status,
  deliveryFareVnd: 15000,
  subtotalVnd: 50000,
  totalVnd: 65000,
  dropoff: const FoodDropoff(lat: 10.77, lng: 106.70, label: 'Q1'),
  lineCount: 1,
  createdAt: '2026-10-26T16:00:00Z',
);

class _Repo implements MerchantOrdersRepository {
  var queue = <MerchantQueueOrder>[];
  @override
  Future<List<MerchantQueueOrder>> listOrderQueue(String accessToken) async =>
      queue;
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  group('push kind mapping', () {
    test('ride, food job and merchant PLACED order map to their sounds', () {
      expect(
        newJobAlertKindForPush({'eventType': 'Ride.request.nearby'}),
        NewJobAlertKind.ride,
      );
      expect(
        newJobAlertKindForPush({'eventType': 'FoodOrder.request.nearby'}),
        NewJobAlertKind.foodJob,
      );
      expect(
        newJobAlertKindForPush({
          'aggregateType': 'FoodOrder',
          'role': 'MERCHANT',
          'status': 'PLACED',
        }),
        NewJobAlertKind.merchantOrder,
      );
      expect(
        newJobAlertKindForPush({
          'aggregateType': 'FoodOrder',
          'role': 'MERCHANT',
          'status': 'PLACED',
          'eventType': 'FoodOrder.change.requested',
        }),
        isNull,
      );
      expect(
        newJobAlertKindForPush({
          'aggregateType': 'FoodOrder',
          'role': 'CUSTOMER',
          'status': 'PLACED',
        }),
        isNull,
      );
      expect(newJobAlertKindForPush({'eventType': 'Chat.message'}), isNull);
    });

    test('names match the backend NEW_JOB_SOUNDS table', () {
      expect(NewJobAlertKind.ride.soundName, 'dealgo_new_ride');
      expect(NewJobAlertKind.ride.androidChannelId, 'dealgo_new_ride_v1');
      expect(
        NewJobAlertKind.foodJob.androidChannelId,
        'dealgo_new_food_job_v1',
      );
      expect(
        NewJobAlertKind.merchantOrder.androidChannelId,
        'dealgo_merchant_new_order_v1',
      );
      expect(
        NewJobAlertKind.merchantOrder.asset,
        'assets/sounds/dealgo_merchant_new_order.mp3',
      );
    });
  });

  group('NewJobAlert', () {
    test('3 jobs within 2 s play the sound once', () async {
      final player = _Player();
      final clock = _Clock();
      final alert = NewJobAlert(player: player, clock: clock.call);
      final data = {
        'eventType': 'Ride.request.nearby',
        'alertSound': 'dealgo_new_ride',
      };
      expect(await alert.handlePush(data), isTrue);
      clock.advance(const Duration(milliseconds: 900));
      expect(await alert.handlePush(data), isFalse);
      clock.advance(const Duration(milliseconds: 900));
      expect(await alert.handlePush(data), isFalse);
      expect(player.played, ['assets/sounds/dealgo_new_ride.mp3']);
      expect(player.vibrations, 1);

      clock.advance(const Duration(seconds: 7));
      expect(await alert.handlePush(data), isTrue);
      expect(player.played, hasLength(2));
    });

    test(
      'push without alertSound (admin/user off) plays the default sound',
      () async {
        final player = _Player();
        final alert = NewJobAlert(player: player);
        await alert.handlePush({'eventType': 'FoodOrder.request.nearby'});
        expect(player.played, ['default']);
        expect(player.vibrations, 1);
      },
    );

    test('non-job pushes play nothing', () async {
      final player = _Player();
      final alert = NewJobAlert(player: player);
      expect(await alert.handlePush({'eventType': 'Chat.message'}), isFalse);
      expect(player.played, isEmpty);
    });

    test(
      'socket trigger honors the local toggle and is skipped on iOS',
      () async {
        SharedPreferences.setMockInitialValues({});
        final android = _Player();
        final a = NewJobAlert(player: android, socketTriggersPlay: true);
        await a.setCustomSound(false);
        await a.handleSocket(NewJobAlertKind.merchantOrder);
        expect(android.played, ['default']);
        final prefs = await SharedPreferences.getInstance();
        expect(prefs.getBool(NewJobAlert.prefKey), isFalse);

        final restored = NewJobAlert(player: _Player());
        await restored.restore();
        expect(restored.customSound, isFalse);

        final ios = _Player();
        final i = NewJobAlert(player: ios, socketTriggersPlay: false);
        expect(await i.handleSocket(NewJobAlertKind.merchantOrder), isFalse);
        expect(ios.played, isEmpty);
      },
    );

    test('during a voice call it only vibrates', () async {
      final player = _Player();
      var calling = true;
      final alert = NewJobAlert(player: player, inCall: () => calling);
      expect(await alert.alert(NewJobAlertKind.ride), isTrue);
      expect(player.played, isEmpty);
      expect(player.vibrations, 1);

      calling = false;
      final later = NewJobAlert(player: player, inCall: () => calling);
      await later.alert(NewJobAlertKind.ride);
      expect(player.played, ['assets/sounds/dealgo_new_ride.mp3']);
    });

    test('built-in sounds ship as assets', () {
      expect(File(AlertAudio.notifyAsset).existsSync(), isTrue);
      expect(File(AlertAudio.ringAsset).existsSync(), isTrue);
    });

    test('a failing player never throws', () async {
      final alert = NewJobAlert(player: _ThrowingPlayer());
      expect(await alert.alert(NewJobAlertKind.ride), isTrue);
    });
  });

  test(
    'merchant queue fires onNewOrders only for unseen PLACED orders',
    () async {
      final rt = FakeSnapshotRealtime();
      final repo = _Repo()..queue = [_order('o1', 'PLACED')];
      var fired = 0;
      final cubit = MerchantQueueCubit(
        listMerchantOrderQueue: ListMerchantOrderQueue(repo),
        realtime: rt,
        onNewOrders: () => fired++,
      );
      await cubit.load('tok');
      expect(fired, 0, reason: 'first load is not a new order');
      await cubit.load('tok');
      expect(fired, 0, reason: 'same order again');
      repo.queue = [_order('o1', 'ACCEPTED'), _order('o2', 'PLACED')];
      await cubit.load('tok');
      expect(fired, 1);
      repo.queue = [_order('o1', 'ACCEPTED'), _order('o2', 'PLACED')];
      await cubit.load('tok');
      expect(fired, 1);
      await cubit.close();
      await rt.dispose();
    },
  );

  test('native channels, sound files and backend names stay in sync', () {
    final kotlin = File(
      'android/app/src/main/kotlin/com/nguyenngoctien/dealgo/NewJobChannels.kt',
    ).readAsStringSync();
    final pbx = File('ios/Runner.xcodeproj/project.pbxproj').readAsStringSync();
    final backend = File('../backend/src/integrations/push/new-job-sound.ts');
    for (final kind in NewJobAlertKind.values) {
      expect(kotlin, contains('"${kind.androidChannelId}"'));
      expect(kotlin, contains(kind.soundName));
      expect(
        File('android/app/src/main/res/raw/${kind.soundName}.ogg').existsSync(),
        isTrue,
      );
      expect(File('ios/Runner/${kind.soundName}.caf').existsSync(), isTrue);
      expect(pbx, contains('${kind.soundName}.caf in Resources'));
      expect(File(kind.asset).existsSync(), isTrue);
      if (backend.existsSync()) {
        expect(backend.readAsStringSync(), contains(kind.soundName));
      }
    }
    expect(kotlin, contains('"$newJobDefaultSoundChannelId"'));
  });
}

class _ThrowingPlayer implements NewJobAlertPlayer {
  @override
  Future<void> playAsset(String asset) async => throw StateError('no file');
  @override
  Future<void> playDefault() async => throw StateError('no file');
  @override
  Future<void> vibrate() async => throw StateError('no vibrator');
}
