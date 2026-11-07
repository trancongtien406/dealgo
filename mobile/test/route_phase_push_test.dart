import 'package:dealgo/core/maps/route_geometry.dart';
import 'package:dealgo/core/realtime/snapshot_realtime.dart';
import 'package:dealgo/features/live_location/presentation/server_phase_route.dart';
import 'package:flutter_test/flutter_test.dart';

RouteGeometry? _geo(List<List<double>> coords, {bool available = true}) =>
    RouteGeometry.tryParse({
      'available': available,
      'provider': 'mapbox',
      'coords': coords,
      'durationSec': 300,
    });

void main() {
  group('routeUpdated (DEC-PROD-031 rev 3, DRAFT)', () {
    test('parses a server leg push', () {
      final hint = parseRouteUpdateHint({
        'aggregateType': 'FoodOrder',
        'aggregateId': 'o1',
        'phase': 'APPROACH',
        'reason': 'OFF_ROUTE',
        'route': {
          'available': true,
          'provider': 'mapbox',
          'coords': [
            [16.05, 108.2],
            [16.06, 108.21],
          ],
          'durationSec': 240,
        },
        'at': '2026-10-24T03:00:00.000Z',
      });
      expect(hint, isNotNull);
      expect(hint!.phase, 'APPROACH');
      expect(hint.reason, 'OFF_ROUTE');
      expect(hint.route.hasRoadPolyline, isTrue);
      expect(hint.route.durationSec, 240);
    });

    test('rejects malformed payloads', () {
      expect(parseRouteUpdateHint({'aggregateId': 'x'}), isNull);
      expect(parseRouteUpdateHint('nope'), isNull);
    });

    test('approach prefers pushed, then seed, then trip; never straight', () {
      final trip = _geo([
        [1, 1],
        [2, 2],
      ]);
      final seed = _geo([
        [0, 0],
        [1, 1],
      ]);
      final pushed = _geo([
        [0.5, 0.5],
        [1, 1],
      ]);
      expect(
        serverPhasePolyline(
          approach: true,
          pushed: pushed,
          approachSeed: seed,
          trip: trip,
        ).first.lat,
        0.5,
      );
      expect(
        serverPhasePolyline(
          approach: true,
          pushed: null,
          approachSeed: seed,
          trip: trip,
        ).first.lat,
        0,
      );
      expect(
        serverPhasePolyline(
          approach: false,
          pushed: null,
          approachSeed: seed,
          trip: trip,
        ).first.lat,
        1,
      );
      // Unavailable pushed leg ⇒ no line at all (no stop-to-stop fallback).
      expect(
        serverPhasePolyline(
          approach: true,
          pushed: _geo(const [], available: false),
          approachSeed: seed,
          trip: trip,
        ),
        isEmpty,
      );
      // When approach seed has no road polyline, falls back to trip.
      expect(
        serverPhasePolyline(
          approach: true,
          pushed: null,
          approachSeed: _geo(const [], available: false),
          trip: trip,
        ).first.lat,
        1,
      );
    });
  });
}
