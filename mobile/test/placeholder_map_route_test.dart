import 'package:dealgo/core/maps/map_lat_lng.dart';
import 'package:dealgo/core/maps/placeholder_map_port.dart';
import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';

/// Without map tiles the route still keeps its real road shape.
void main() {
  test('projection keeps relative positions and fits the box', () {
    const a = MapLatLng(lat: 10.7769, lng: 106.7009); // north-west
    const b = MapLatLng(lat: 10.7880, lng: 106.7050); // further north
    const c = MapLatLng(lat: 10.7700, lng: 106.7200); // south-east
    final project = PlaceholderProjection.fit([a, b, c], const Size(400, 300))!;
    final pa = project(a), pb = project(b), pc = project(c);
    expect(pb.dy, lessThan(pa.dy)); // north is up
    expect(pc.dx, greaterThan(pa.dx)); // east is right
    for (final p in [pa, pb, pc]) {
      expect(p.dx, inInclusiveRange(40, 360));
      expect(p.dy, inInclusiveRange(40, 260));
    }
  });

  test('no projection for a single point', () {
    const a = MapLatLng(lat: 10.7769, lng: 106.7009);
    expect(PlaceholderProjection.fit([a, a], const Size(400, 300)), isNull);
  });

  test('route ends map to the pickup and dropoff spots', () {
    const pickup = MapLatLng(lat: 10.7769, lng: 106.7009);
    const dropoff = MapLatLng(lat: 10.7900, lng: 106.7200);
    final project = PlaceholderProjection.fit([
      pickup,
      const MapLatLng(lat: 10.7800, lng: 106.7100),
      dropoff,
    ], const Size(400, 300))!;
    expect(project(pickup).dx, lessThan(project(dropoff).dx));
    expect(project(pickup).dy, greaterThan(project(dropoff).dy));
  });
}
