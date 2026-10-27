import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/maps/map_lat_lng.dart';
import '../../../core/maps/route_geometry.dart';
import '../../../core/realtime/snapshot_realtime.dart';
import '../../identity/domain/entities/auth_state.dart';
import '../../identity/presentation/cubit/auth_cubit.dart';
import '../domain/driver_location.dart';

/// Driver-side phase route (DEC-PROD-031 rev 3, DRAFT). While [active] it
/// joins the `ride:` / `food:` room and swaps in each server `routeUpdated`
/// leg for the current phase. No client Directions calls, no polling, and
/// never a straight line: an unavailable leg draws nothing.
///
/// [approach] true ⇒ wants the APPROACH leg (driver→pickup/store), seeded by
/// [approachSeed] (REST snapshot). Otherwise the TRIP leg, seeded by [trip].
class ServerPhaseRoute extends StatefulWidget {
  const ServerPhaseRoute({
    required this.job,
    required this.id,
    required this.active,
    required this.approach,
    required this.trip,
    required this.builder,
    this.approachSeed,
    super.key,
  });

  final TrackedJob job;
  final String id;
  final bool active;
  final bool approach;
  final RouteGeometry? trip;
  final RouteGeometry? approachSeed;
  final Widget Function(BuildContext context, List<MapLatLng> route) builder;

  @override
  State<ServerPhaseRoute> createState() => _ServerPhaseRouteState();
}

/// Polyline to draw for [phase] given the latest pushed leg (may be null).
@visibleForTesting
List<MapLatLng> serverPhasePolyline({
  required bool approach,
  required RouteGeometry? pushed,
  required RouteGeometry? approachSeed,
  required RouteGeometry? trip,
}) {
  final leg = pushed ?? (approach ? (approachSeed ?? trip) : trip);
  if (leg == null || !leg.hasRoadPolyline) {
    return const [];
  }
  return leg.coords;
}

class _ServerPhaseRouteState extends State<ServerPhaseRoute> {
  StreamSubscription<RouteUpdateHint>? _sub;
  SnapshotRealtime? _realtime;
  SnapshotRoom? _room;
  RouteGeometry? _pushed;

  String get _phase => widget.approach ? 'APPROACH' : 'TRIP';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _sync());
  }

  @override
  void didUpdateWidget(ServerPhaseRoute oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.approach != widget.approach || oldWidget.id != widget.id) {
      _pushed = null;
    }
    if (oldWidget.active != widget.active || oldWidget.id != widget.id) {
      _sync();
    }
  }

  void _sync() {
    _stop();
    if (!mounted || !widget.active) {
      return;
    }
    final auth = context.read<AuthCubit>().state;
    if (auth is! AuthSignedIn) {
      return;
    }
    SnapshotRealtime realtime;
    try {
      realtime = context.read<SnapshotRealtime>();
    } on ProviderNotFoundException {
      return;
    }
    final room = widget.job == TrackedJob.ride
        ? RideSnapshotRoom(widget.id) as SnapshotRoom
        : FoodSnapshotRoom(widget.id);
    _realtime = realtime;
    _room = room;
    _sub = realtime.routeUpdates.listen(_onRoute);
    unawaited(() async {
      await realtime.connect(accessToken: auth.tokens.accessToken);
      await realtime.subscribe(room);
    }());
  }

  void _onRoute(RouteUpdateHint hint) {
    final type = widget.job == TrackedJob.ride ? 'Ride' : 'FoodOrder';
    if (!mounted ||
        hint.aggregateType != type ||
        hint.aggregateId != widget.id ||
        hint.phase != _phase) {
      return;
    }
    setState(() => _pushed = hint.route);
  }

  void _stop() {
    unawaited(_sub?.cancel());
    _sub = null;
    final realtime = _realtime;
    final room = _room;
    _realtime = null;
    _room = null;
    if (realtime != null && room != null) {
      unawaited(realtime.unsubscribe(room));
    }
  }

  @override
  void dispose() {
    _stop();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.builder(
    context,
    serverPhasePolyline(
      approach: widget.approach,
      pushed: _pushed,
      approachSeed: widget.approachSeed,
      trip: widget.trip,
    ),
  );
}
