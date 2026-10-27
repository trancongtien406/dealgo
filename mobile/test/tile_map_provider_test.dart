import 'package:dealgo/core/maps/map_lat_lng.dart';
import 'package:dealgo/core/maps/tile_map_port.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_test/flutter_test.dart';

/// Rebuilds (driver glide, route pulse) must keep one tile provider, else
/// every frame restarts tile downloads and the map stays blank.
void main() {
  Widget map(MapLatLng driver) => MaterialApp(
    home: SizedBox(
      width: 400,
      height: 600,
      child: TileMapView(
        urlTemplate: 'https://tiles.invalid/{z}/{x}/{y}.png',
        center: const MapLatLng(lat: 10.776, lng: 106.7009),
        markers: const [
          MapLatLng(lat: 10.776, lng: 106.7009),
          MapLatLng(lat: 10.79, lng: 106.71),
        ],
        route: const [
          MapLatLng(lat: 10.776, lng: 106.7009),
          MapLatLng(lat: 10.785, lng: 106.705),
          MapLatLng(lat: 10.79, lng: 106.71),
        ],
        driver: driver,
        pulseRoute: true,
      ),
    ),
  );

  testWidgets('the tile provider survives rebuilds', (tester) async {
    await tester.pumpWidget(map(const MapLatLng(lat: 10.77, lng: 106.70)));
    final first = tester.widget<TileLayer>(find.byType(TileLayer)).tileProvider;
    await tester.pumpWidget(map(const MapLatLng(lat: 10.771, lng: 106.701)));
    await tester.pumpWidget(map(const MapLatLng(lat: 10.772, lng: 106.702)));
    final later = tester.widget<TileLayer>(find.byType(TileLayer)).tileProvider;
    expect(identical(first, later), isTrue);
    expect(find.byKey(const Key('map-live-route')), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
  });
}
