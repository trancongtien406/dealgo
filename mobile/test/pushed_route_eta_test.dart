import 'package:dealgo/core/realtime/snapshot_realtime.dart';
import 'package:dealgo/features/activity/domain/entities/history_models.dart';
import 'package:dealgo/features/shell/presentation/customer_activity_page.dart';
import 'package:dealgo/features/live_location/presentation/pushed_route_eta.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:dealgo/core/realtime/fake_snapshot_realtime.dart';

RouteUpdateHint _hint(String phase, int sec, {String id = 'o1'}) =>
    parseRouteUpdateHint({
      'aggregateType': 'FoodOrder',
      'aggregateId': id,
      'phase': phase,
      'reason': 'OFF_ROUTE',
      'route': {
        'available': true,
        'provider': 'mapbox',
        'coords': [
          [10.78, 106.70],
          [10.79, 106.69],
        ],
        'durationSec': sec,
      },
      'at': '2026-10-24T13:00:00.000Z',
    })!;

void main() {
  test('accepts only same aggregate + phase', () {
    int? f(RouteUpdateHint h, String? phase) => acceptedPushedEtaSec(
      h,
      aggregateType: 'FoodOrder',
      id: 'o1',
      phase: phase,
    );
    expect(f(_hint('APPROACH', 420), 'APPROACH'), 420);
    expect(f(_hint('TRIP', 420), 'APPROACH'), isNull);
    expect(f(_hint('APPROACH', 420, id: 'x'), 'APPROACH'), isNull);
    expect(f(_hint('APPROACH', 420), null), isNull);
  });

  testWidgets('sheet ETA updates live from routeUpdated push', (tester) async {
    final rt = FakeSnapshotRealtime();
    await tester.pumpWidget(
      RepositoryProvider<SnapshotRealtime>.value(
        value: rt,
        child: MaterialApp(
          home: PushedRouteEta(
            aggregateType: 'FoodOrder',
            id: 'o1',
            phase: 'APPROACH',
            fallbackSec: 600,
            builder: (_, sec) => Text('eta:$sec'),
          ),
        ),
      ),
    );
    expect(find.text('eta:600'), findsOneWidget);
    rt.emitRouteUpdate(_hint('TRIP', 120)); // stale phase ignored
    await tester.pump();
    await tester.pump();
    expect(find.text('eta:600'), findsOneWidget);
    rt.emitRouteUpdate(_hint('APPROACH', 240));
    await tester.pump();
    await tester.pump();
    expect(find.text('eta:240'), findsOneWidget);
  });

  test('activity row opens the matching tracking screen', () {
    HistoryItem h(HistoryKind k) => HistoryItem(
      id: 'x1',
      kind: k,
      title: 't',
      meta: 'm',
      status: 'ASSIGNED',
      amountVnd: null,
    );
    expect(historyDetailPath(h(HistoryKind.food)), '/customer/food/orders/x1');
    expect(
      historyDetailPath(h(HistoryKind.ride)),
      '/customer/ride/tracking/x1',
    );
  });
}
