import 'dart:io';

import 'package:dealgo/core/maps/map_lat_lng.dart';
import 'package:dealgo/core/maps/map_markers.dart';
import 'package:dealgo/core/maps/map_port.dart';
import 'package:dealgo/features/driver/presentation/widgets/driver_duty_map.dart';
import 'package:dealgo/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';

class _RecordingMapPort implements MapPort {
  int calls = 0;
  MapLatLng? center;
  MapLatLng? driver;
  List<MapLatLng> markers = const [];
  List<MapLatLng> route = const [];
  MapVehicleKind? vehicle;

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
    calls++;
    this.center = center;
    this.driver = driver;
    this.markers = markers;
    this.route = route;
    vehicle = driverVehicle;
    return SizedBox.expand(key: key);
  }
}

Future<_RecordingMapPort> _pump(
  WidgetTester tester, {
  required bool online,
  Future<MapLatLng?> Function()? readFix,
  List<MapLatLng> demand = const [],
  String? vehicle,
}) async {
  final port = _RecordingMapPort();
  await tester.pumpWidget(
    RepositoryProvider<MapPort>.value(
      value: port,
      child: MaterialApp(
        locale: const Locale('vi'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: DriverDutyMap(
            online: online,
            vehicleClassCode: vehicle,
            demand: demand,
            readFix: readFix,
          ),
        ),
      ),
    ),
  );
  await tester.pump();
  await tester.pump();
  return port;
}

void main() {
  const me = MapLatLng(lat: 16.0600, lng: 108.2200);
  const near = MapLatLng(lat: 16.0650, lng: 108.2250); // ~0.8 km
  const far = MapLatLng(lat: 16.4600, lng: 107.5900); // Huế, ~80 km

  testWidgets('overview map goes through MapPort with the real GPS marker', (
    tester,
  ) async {
    final port = await _pump(
      tester,
      online: true,
      readFix: () async => me,
      demand: const [far, near],
      vehicle: 'CAR_7',
    );
    expect(port.calls, greaterThan(0));
    expect(port.driver, me);
    expect(port.center, me);
    expect(port.vehicle, MapVehicleKind.car7);
    // Tiles only: never a route, so no Directions call.
    expect(port.route, isEmpty);
    // Demand hints: only open jobs near the driver.
    expect(port.markers, const [near]);
    expect(find.byKey(const Key('driver-duty-map-online')), findsOneWidget);
    expect(find.text('Đang nhận việc'), findsOneWidget);
    expect(
      find.byType(CustomPaint).evaluate().where((e) {
        final w = e.widget as CustomPaint;
        return w.painter != null &&
            w.painter.runtimeType.toString().contains('Map');
      }),
      isEmpty,
    );
  });

  testWidgets('without a fix it centres on Đà Nẵng and shows no fake marker', (
    tester,
  ) async {
    final port = await _pump(
      tester,
      online: false,
      readFix: () async => null,
      demand: const [near],
    );
    expect(port.driver, isNull);
    expect(port.center, danangViewportCenter);
    expect(port.markers, isEmpty);
    expect(find.byKey(const Key('driver-duty-map-offline')), findsOneWidget);
  });

  test('no screen draws a hand-made map with a CustomPainter', () {
    final offenders = <String>[];
    for (final f in Directory('lib/features').listSync(recursive: true)) {
      if (f is! File || !f.path.endsWith('.dart')) continue;
      final src = f.readAsStringSync();
      if (RegExp(r'class \w*Map\w*Painter extends CustomPainter')
          .hasMatch(src)) {
        offenders.add(f.path);
      }
    }
    expect(offenders, isEmpty);
    final home = File(
      'lib/features/driver/presentation/pages/driver_home_page.dart',
    ).readAsStringSync();
    expect(home, contains('DriverDutyMap('));
    expect(home, isNot(contains('_DutyMapPainter')));
  });
}
