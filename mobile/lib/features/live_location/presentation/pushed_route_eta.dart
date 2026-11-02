import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/maps/map_lat_lng.dart';
import '../../../core/maps/route_geometry.dart';
import '../../../core/realtime/snapshot_realtime.dart';

/// Live ETA with no extra routing request (DEC-PROD-035).
///
/// The server keeps ONE cached road leg per phase (REST `approachRoute` /
/// `route`, or a `routeUpdated` push after a throttled re-route). The ETA is
/// that leg's duration scaled by how much of the leg is still ahead of the
/// driver's latest `driverLocation` fix — so it counts down on every GPS ping
/// without calling Directions. Room subscriptions are owned by the map on the
/// same screen. A phase change drops the stale leg.
class PushedRouteEta extends StatefulWidget {
  const PushedRouteEta({
    required this.aggregateType,
    required this.id,
    required this.phase,
    required this.fallbackSec,
    required this.builder,
    this.seedRoute,
    super.key,
  });

  /// `Ride` | `FoodOrder`.
  final String aggregateType;
  final String id;

  /// `APPROACH` | `TRIP`, or null when no route leg is live.
  final String? phase;
  final int? fallbackSec;

  /// The REST snapshot leg for [phase] (cached server-side).
  final RouteGeometry? seedRoute;
  final Widget Function(BuildContext context, int? durationSec) builder;

  @override
  State<PushedRouteEta> createState() => _PushedRouteEtaState();
}

/// Pure acceptance rule (tested): does [hint] update this screen's ETA?
int? acceptedPushedEtaSec(
  RouteUpdateHint hint, {
  required String aggregateType,
  required String id,
  required String? phase,
}) {
  if (phase == null) return null;
  if (hint.aggregateType != aggregateType || hint.aggregateId != id) {
    return null;
  }
  if (hint.phase != phase || !hint.route.hasRoadPolyline) return null;
  final sec = hint.route.durationSec;
  return sec != null && sec > 0 ? sec : null;
}

double _metres(MapLatLng a, MapLatLng b) {
  const r = 6371000.0;
  final lat1 = a.lat * math.pi / 180;
  final lat2 = b.lat * math.pi / 180;
  final dLat = lat2 - lat1;
  final dLng = (b.lng - a.lng) * math.pi / 180;
  final h =
      math.pow(math.sin(dLat / 2), 2) +
      math.cos(lat1) * math.cos(lat2) * math.pow(math.sin(dLng / 2), 2);
  return 2 * r * math.asin(math.min(1, math.sqrt(h)));
}

/// Share (0–1) of [coords] still ahead of [at]: the point is projected on the
/// nearest segment, remaining length / total length. 1 when unknown.
double remainingRouteFraction(List<MapLatLng> coords, MapLatLng at) {
  if (coords.length < 2) return 1;
  final segLen = <double>[];
  var total = 0.0;
  for (var i = 0; i + 1 < coords.length; i += 1) {
    final len = _metres(coords[i], coords[i + 1]);
    segLen.add(len);
    total += len;
  }
  if (total <= 0) return 1;
  // Local equirectangular frame around [at] (fine for a few km).
  final kx = math.cos(at.lat * math.pi / 180);
  var best = double.infinity;
  var ahead = total;
  var before = 0.0;
  for (var i = 0; i < segLen.length; i += 1) {
    final a = coords[i];
    final b = coords[i + 1];
    final ax = (a.lng - at.lng) * kx;
    final ay = a.lat - at.lat;
    final bx = (b.lng - at.lng) * kx;
    final by = b.lat - at.lat;
    final dx = bx - ax;
    final dy = by - ay;
    final len2 = dx * dx + dy * dy;
    final t = len2 == 0 ? 0.0 : (-(ax * dx + ay * dy) / len2).clamp(0.0, 1.0);
    final px = ax + dx * t;
    final py = ay + dy * t;
    final d2 = px * px + py * py;
    if (d2 < best) {
      best = d2;
      ahead = total - before - segLen[i] * t;
    }
    before += segLen[i];
  }
  return (ahead / total).clamp(0.0, 1.0);
}

/// ETA seconds for [route] with the driver at [driver] (null = not moving yet).
int? remainingRouteSec(RouteGeometry? route, MapLatLng? driver) {
  final total = route?.durationSec;
  if (route == null || !route.hasRoadPolyline || total == null || total <= 0) {
    return null;
  }
  if (driver == null) return total;
  final left = (total * remainingRouteFraction(route.coords, driver)).round();
  return math.max(60, left);
}

class _PushedRouteEtaState extends State<PushedRouteEta> {
  StreamSubscription<RouteUpdateHint>? _routeSub;
  StreamSubscription<DriverLocationHint>? _locationSub;
  RouteGeometry? _pushed;
  MapLatLng? _driver;

  @override
  void initState() {
    super.initState();
    SnapshotRealtime? realtime;
    try {
      realtime = context.read<SnapshotRealtime>();
    } catch (_) {
      realtime = null;
    }
    _routeSub = realtime?.routeUpdates.listen((hint) {
      final sec = acceptedPushedEtaSec(
        hint,
        aggregateType: widget.aggregateType,
        id: widget.id,
        phase: widget.phase,
      );
      if (sec != null && mounted) setState(() => _pushed = hint.route);
    });
    _locationSub = realtime?.driverLocations.listen((hint) {
      if (hint.aggregateType != widget.aggregateType ||
          hint.aggregateId != widget.id ||
          !mounted) {
        return;
      }
      setState(() => _driver = MapLatLng(lat: hint.lat, lng: hint.lng));
    });
  }

  @override
  void didUpdateWidget(PushedRouteEta old) {
    super.didUpdateWidget(old);
    if (old.phase != widget.phase || old.id != widget.id) _pushed = null;
  }

  @override
  void dispose() {
    unawaited(_routeSub?.cancel());
    unawaited(_locationSub?.cancel());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.phase == null) {
      return widget.builder(context, widget.fallbackSec);
    }
    final leg = _pushed ?? widget.seedRoute;
    final live = remainingRouteSec(leg, _driver);
    return widget.builder(context, live ?? widget.fallbackSec);
  }
}
