import 'package:dealgo/core/maps/map_lat_lng.dart';
import 'package:dealgo/core/maps/map_markers.dart';
import 'package:dealgo/core/maps/map_port.dart';
import 'package:dealgo/features/driver/presentation/pages/driver_food_page.dart';
import 'package:dealgo/features/food/data/datasources/dio_food_remote_datasource.dart';
import 'package:dealgo/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';

class _RecordingMapPort implements MapPort {
  List<MapLatLng> lastRoute = const [];

  @override
  Widget buildMap({
    required MapLatLng center,
    List<MapLatLng> markers = const [],
    MapLatLng? driver,
    List<MapLatLng> route = const [],
    bool pulseRoute = false,
    EdgeInsets fitPadding = const EdgeInsets.all(32),
    MapVehicleKind driverVehicle = MapVehicleKind.motorbike,
    bool firstMarkerIsPickup = true,
    MapStopStyle stopStyle = MapStopStyle.ride,
    double? driverHeading,
    Duration? driverGlide,
    Key? key,
  }) {
    lastRoute = route;
    return const SizedBox.expand();
  }
}

Map<String, Object?> _row({Object? route}) => {
  'id': 'o1',
  'storeId': 's1',
  'storeName': 'Quán',
  'deliveryFareVnd': 15000,
  'subtotalVnd': 50000,
  'totalVnd': 65000,
  'lineCount': 1,
  'dropoff': {'lat': 16.06, 'lng': 108.21, 'label': 'Nhà'},
  'pickup': {'lat': 16.0544, 'lng': 108.2022, 'label': 'Quán'},
  'route': ?route,
};

Future<List<MapLatLng>> _pump(
  WidgetTester tester,
  Map<String, Object?> row,
) async {
  final job = decodeReadyFoodJobs({
    'success': true,
    'data': [row],
  }).single;
  final port = _RecordingMapPort();
  await tester.pumpWidget(
    RepositoryProvider<MapPort>.value(
      value: port,
      child: MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(body: DriverFoodJobMap(job: job)),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return port.lastRoute;
}

void main() {
  testWidgets('driver food map draws the road coords from the ready payload', (
    tester,
  ) async {
    final route = await _pump(
      tester,
      _row(
        route: {
          'available': true,
          'provider': 'mapbox',
          'coords': [
            [16.0544, 108.2022],
            [16.057, 108.205],
            [16.06, 108.21],
          ],
        },
      ),
    );
    expect(route, hasLength(3));
    expect(route[1].lat, 16.057);
  });

  testWidgets('no route → no line (never a straight store→customer segment)', (
    tester,
  ) async {
    expect(await _pump(tester, _row()), isEmpty);
    expect(
      await _pump(
        tester,
        _row(route: {'available': false, 'provider': 'none', 'coords': []}),
      ),
      isEmpty,
    );
  });
}
