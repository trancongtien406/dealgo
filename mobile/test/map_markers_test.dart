import 'dart:io';
import 'dart:ui' as ui;

import 'package:dealgo/core/maps/map_lat_lng.dart';
import 'package:dealgo/core/maps/map_markers.dart';
import 'package:dealgo/core/maps/tile_map_port.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('mapVehicleForClass maps Ride classes; unknown/food → motorbike', () {
    expect(mapVehicleForClass('MOTORBIKE'), MapVehicleKind.motorbike);
    expect(mapVehicleForClass('CAR_4'), MapVehicleKind.car4);
    expect(mapVehicleForClass('car_7'), MapVehicleKind.car7);
    expect(mapVehicleForClass(''), MapVehicleKind.motorbike);
    expect(mapVehicleForClass(null), MapVehicleKind.motorbike);
  });

  test('bearingDegrees: N/E/S/W and null on no movement', () {
    const o = MapLatLng(lat: 16.06, lng: 108.22);
    expect(
      bearingDegrees(o, const MapLatLng(lat: 16.07, lng: 108.22)),
      closeTo(0, 0.5),
    );
    expect(
      bearingDegrees(o, const MapLatLng(lat: 16.06, lng: 108.23)),
      closeTo(90, 0.5),
    );
    expect(
      bearingDegrees(o, const MapLatLng(lat: 16.05, lng: 108.22)),
      closeTo(180, 0.5),
    );
    expect(
      bearingDegrees(o, const MapLatLng(lat: 16.06, lng: 108.21)),
      closeTo(270, 0.5),
    );
    expect(bearingDegrees(o, o), isNull);
    expect(
      bearingAlong(const [o, o, MapLatLng(lat: 16.06, lng: 108.23)]),
      closeTo(90, 0.5),
    );
  });

  testWidgets('stop pins: glyph + chip per kind, no A/B letters', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: Row(
            children: [
              DealGoMapPin(kind: DealGoMapPinKind.pickup),
              DealGoMapPin(kind: DealGoMapPinKind.dropoff),
              DealGoMapPin(kind: DealGoMapPinKind.store),
              DealGoMapPin(kind: DealGoMapPinKind.home),
            ],
          ),
        ),
      ),
    );
    for (final (kind, icon, label) in [
      (DealGoMapPinKind.pickup, Icons.person_rounded, 'Đón'),
      (DealGoMapPinKind.dropoff, Icons.flag_rounded, 'Đến'),
      (DealGoMapPinKind.store, Icons.storefront_rounded, 'Quán'),
      (DealGoMapPinKind.home, Icons.home_rounded, 'Giao'),
    ]) {
      expect(find.byKey(Key('map-pin-${kind.name}')), findsOneWidget);
      expect(find.byIcon(icon), findsOneWidget);
      expect(find.text(label), findsOneWidget);
    }
    expect(find.text('A'), findsNothing);
    expect(find.text('B'), findsNothing);
  });

  test('pin kind per stop style and tip alignment', () {
    expect(
      mapPinKindFor(0, firstMarkerIsPickup: true),
      DealGoMapPinKind.pickup,
    );
    expect(
      mapPinKindFor(0, firstMarkerIsPickup: false),
      DealGoMapPinKind.dropoff,
    );
    expect(
      mapPinKindFor(0, firstMarkerIsPickup: true, style: MapStopStyle.food),
      DealGoMapPinKind.store,
    );
    expect(
      mapPinKindFor(1, firstMarkerIsPickup: true, style: MapStopStyle.food),
      DealGoMapPinKind.home,
    );
    // Tip (bottom of the pin) ends up within 1 px of the coordinate.
    const size = 42.0;
    final box = DealGoMapPin.boxFor(size);
    final a = DealGoMapPin.markerAlignment(size);
    // flutter_map: child top = point.y - h/2 * (1 + a.y) … tip offset.
    final childTop = -box.height / 2 * (1 - a.y);
    final tipY = childTop + box.height - size * 0.04;
    expect(tipY.abs(), lessThan(1.0));
  });

  testWidgets('driver marker paints vehicle by class and rotates by heading', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Row(
            children: [
              DealGoDriverMarker(
                key: const Key('bike'),
                vehicle: mapVehicleForClass('MOTORBIKE'),
                heading: 90,
              ),
              DealGoDriverMarker(
                key: const Key('car'),
                vehicle: mapVehicleForClass('CAR_4'),
              ),
            ],
          ),
        ),
      ),
    );
    CustomPaint paintOf(String k) => tester.widget<CustomPaint>(
      find
          .descendant(
            of: find.byKey(Key(k)),
            matching: find.byType(CustomPaint),
          )
          .first,
    );
    expect(
      (paintOf('bike').painter! as TopDownVehiclePainter).vehicle,
      MapVehicleKind.motorbike,
    );
    expect(
      (paintOf('car').painter! as TopDownVehiclePainter).vehicle,
      MapVehicleKind.car4,
    );
    final rot = tester.widget<Transform>(
      find.descendant(
        of: find.byKey(const Key('bike')),
        matching: find.byType(Transform),
      ),
    );
    // 90° → rotation matrix entry m[1] (sin) == 1.
    expect(rot.transform.storage[1], closeTo(1, 1e-6));
  });

  testWidgets('render marker preview PNG (DEALGO_MARKER_PREVIEW)', (
    tester,
  ) async {
    final out = Platform.environment['DEALGO_MARKER_PREVIEW'];
    if (out == null) {
      return;
    }
    final key = GlobalKey();
    await tester.binding.setSurfaceSize(const Size(980, 190));
    await tester.pumpWidget(
      MaterialApp(
        debugShowCheckedModeBanner: false,
        home: RepaintBoundary(
          key: key,
          child: Container(
            color: const Color(0xFFE9EEF3),
            padding: const EdgeInsets.all(20),
            child: const Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                DealGoMapPin(kind: DealGoMapPinKind.pickup, size: 64),
                DealGoMapPin(kind: DealGoMapPinKind.dropoff, size: 64),
                DealGoMapPin(kind: DealGoMapPinKind.store, size: 64),
                DealGoMapPin(kind: DealGoMapPinKind.home, size: 64),
                DealGoDriverMarker(size: 80),
                DealGoDriverMarker(
                  size: 80,
                  vehicle: MapVehicleKind.car4,
                  heading: 35,
                ),
                DealGoDriverMarker(
                  size: 80,
                  vehicle: MapVehicleKind.car7,
                  heading: 90,
                ),
              ],
            ),
          ),
        ),
      ),
    );
    await tester.runAsync(() async {
      final boundary =
          key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
      final image = await boundary.toImage(pixelRatio: 3);
      final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
      File(out).writeAsBytesSync(bytes!.buffer.asUint8List());
    });
  });

  test('fit padding leaves room for the whole pin + chip above its point', () {
    final box = DealGoMapPin.boxFor(42);
    final padded = stopPinSafeFitPadding(const EdgeInsets.all(32), 42);
    expect(padded.top, greaterThanOrEqualTo(box.height));
    expect(padded.left, greaterThanOrEqualTo(box.width / 2));
    expect(padded.right, greaterThanOrEqualTo(box.width / 2));
    expect(padded.bottom, 32);
    const roomy = EdgeInsets.fromLTRB(80, 120, 80, 40);
    expect(stopPinSafeFitPadding(roomy, 42), roomy);
  });
}
