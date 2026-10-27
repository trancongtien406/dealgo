import 'package:dealgo/l10n/app_localizations.dart';
import 'package:dealgo/features/presence/domain/usecases/set_presence.dart';
import 'package:dealgo/features/presence/data/repositories/presence_repository_impl.dart';
import 'package:dealgo/features/activity/domain/usecases/list_ride_history.dart';
import 'package:dealgo/features/activity/domain/usecases/list_food_history.dart';
import 'package:dealgo/features/activity/data/repositories/history_repository_impl.dart';
import 'package:dealgo/core/maps/create_map_port.dart';
import 'package:dealgo/core/maps/map_lat_lng.dart';
import 'package:dealgo/core/maps/placeholder_map_port.dart';
import 'package:dealgo/core/network/api_paths.dart';
import 'package:dealgo/core/push/fake_push.dart';
import 'package:dealgo/features/activity/data/datasources/dio_history_remote_datasource.dart';
import 'package:dealgo/features/activity/data/datasources/fake_history_client.dart';
import 'package:dealgo/features/activity/domain/entities/history_models.dart';
import 'package:dealgo/features/activity/presentation/cubit/activity_history_cubit.dart';
import 'package:dealgo/features/driver/presentation/cubit/driver_duty_cubit.dart';
import 'package:dealgo/features/presence/data/datasources/fake_presence_client.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('ApiPaths expose push, presence, voice and history routes', () {
    expect(ApiPaths.mePushTokens, '/v1/me/push-tokens');
    expect(ApiPaths.mePresence, '/v1/me/presence');
    expect(ApiPaths.meRides, '/v1/rides');
    expect(ApiPaths.meFoodOrders, '/v1/food/orders');
    expect(ApiPaths.rideCalls('r1'), '/v1/rides/r1/calls');
    expect(ApiPaths.foodOrderCalls('o1'), '/v1/food/orders/o1/calls');
    expect(ApiPaths.callsConfig, '/v1/calls/config');
    expect(ApiPaths.callAction('c1', 'accept'), '/v1/calls/c1/accept');
  });

  test('FakePush registers without network', () async {
    final push = FakePush();
    await push.ensureRegistered(accessToken: 'tok');
    expect(await push.currentToken(), 'fake-fcm-token');
    expect(push.registerCalls, ['tok']);
  });

  test('DriverDutyCubit posts presence when going online', () async {
    final presence = FakePresenceClient();
    final duty = DriverDutyCubit(
      setPresence: SetPresence(PresenceRepositoryImpl(presence)),
      accessToken: () => 'access-token',
    );
    await duty.connect();
    expect(duty.state, isTrue);
    expect(presence.calls.single.online, isTrue);

    await duty.disconnect();
    expect(duty.state, isFalse);
    expect(presence.calls.last.online, isFalse);
    await duty.close();
  });

  test('ActivityHistoryCubit loads ride and food lists', () async {
    final history = FakeHistoryClient();
    final repo = HistoryRepositoryImpl(history);
    final cubit = ActivityHistoryCubit(
      listRideHistory: ListRideHistory(repo),
      listFoodHistory: ListFoodHistory(repo),
    );
    await cubit.load(accessToken: 'access-token');
    final state = cubit.state;
    expect(state, isA<ActivityHistoryReady>());
    expect(state.rides, isNotEmpty);
    expect(state.food, isNotEmpty);
    expect(history.rideCalls, ['access-token']);
    expect(history.foodCalls, ['access-token']);
    await cubit.close();
  });

  test('decodeHistoryList maps ride dropoff label', () {
    final items = decodeHistoryList({
      'success': true,
      'data': [
        {
          'id': 'ride-1',
          'status': 'COMPLETED',
          'agreedFareVnd': 50000,
          'dropoff': {'label': 'Sân bay'},
          'createdAt': '2026-10-14',
        },
      ],
    }, kind: HistoryKind.ride);
    expect(items.single.title, 'Sân bay');
    expect(items.single.amountVnd, 50000);
  });

  testWidgets(
    'PlaceholderMapPort is labelled as illustrative and invents no place',
    (tester) async {
      final port = createMapPort();
      expect(port, isA<PlaceholderMapPort>());
      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          locale: const Locale('vi'),
          home: Scaffold(
            body: port.buildMap(
              center: const MapLatLng(lat: 16.0544, lng: 108.2022),
            ),
          ),
        ),
      );
      expect(find.byKey(const Key('map-placeholder')), findsOneWidget);
      expect(find.text('Bản đồ minh họa'), findsOneWidget);
      expect(find.textContaining('Hải Châu'), findsNothing);
      expect(find.text('SÔNG HÀN'), findsNothing);
    },
  );
}
