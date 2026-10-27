import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/design_system/icons/dealgo_icons.dart';
import '../../../core/design_system/tokens/dealgo_tokens.dart';
import '../../../core/maps/live_route.dart';
import '../../../core/maps/map_lat_lng.dart';
import '../../../core/maps/map_markers.dart';
import '../../../core/maps/map_port.dart';
import '../../../core/maps/route_geometry.dart';
import '../../../core/realtime/snapshot_realtime.dart';
import '../../../l10n/app_localizations.dart';
import '../../identity/domain/entities/auth_state.dart';
import '../../identity/presentation/cubit/auth_cubit.dart';
import '../domain/driver_location.dart';

/// Map for an active job that adds the assigned driver's live position
/// (DEC-PROD-031). While [tracking] is true it is **push-based**: it joins the
/// customer-only `ride-location:` / `food-location:` socket room and moves the
/// driver on each `driverLocation` event. REST `GET .../driver-location` is
/// only the initial snapshot and the reconnect fallback — there is no timer
/// poll. A missing or stale position simply shows the stops.
///
/// When [phase] is [LiveRoutePhase.toPickup] / [LiveRoutePhase.toDropoff], the
/// polyline is the **server-computed** leg (DEC-PROD-031 rev 3, DRAFT): the
/// REST snapshot seeds it via [serverRoute] and the `routeUpdated` push on the
/// `ride:` / `food:` room replaces it (Nest throttles + re-routes off-route).
/// The client never calls Directions itself and never draws a straight line.
class LiveDriverMap extends StatefulWidget {
  const LiveDriverMap({
    required this.job,
    required this.id,
    required this.tracking,
    required this.center,
    this.markers = const [],
    this.route = const [],
    this.roadFollowed = false,
    this.phase = LiveRoutePhase.staticStops,
    this.liveRouteTo,
    this.pulseRoute = true,
    this.vehicle = MapVehicleKind.motorbike,
    this.firstMarkerIsPickup = true,
    this.serverRoute,
    this.onRouteUpdate,
    this.sheetFraction = 0,
    super.key,
  });

  final TrackedJob job;
  final String id;
  final bool tracking;
  final MapLatLng center;
  final List<MapLatLng> markers;

  /// Booked / quote polyline (A→B). Used while [phase] is staticStops or as
  /// fallback before the first live re-route returns.
  final List<MapLatLng> route;

  /// True when [route] is Nest road geometry (kept intact in staticStops).
  final bool roadFollowed;

  /// Tracking phase controls whether the line follows the driver.
  final LiveRoutePhase phase;

  /// Destination of the live remaining path (pickup or dropoff).
  final MapLatLng? liveRouteTo;

  final bool pulseRoute;

  /// Top-down vehicle for the driver marker (Ride class / Food = motorbike).
  final MapVehicleKind vehicle;

  /// False after PICKED_UP — only the dropoff pin remains.
  final bool firstMarkerIsPickup;

  /// Server leg from the REST snapshot (`approachRoute` while APPROACH).
  final RouteGeometry? serverRoute;

  /// Called with each pushed leg (for ETA chips; never invented client-side).
  final ValueChanged<RouteGeometry>? onRouteUpdate;

  /// Fraction of the map height covered by a bottom sheet. The camera fit
  /// keeps the route + stops above it instead of hiding them underneath.
  final double sheetFraction;

  @override
  State<LiveDriverMap> createState() => _LiveDriverMapState();
}

class _LiveDriverMapState extends State<LiveDriverMap> {
  StreamSubscription<DriverLocationHint>? _pushSub;
  StreamSubscription<void>? _reconnectSub;
  StreamSubscription<RouteUpdateHint>? _routeSub;
  SnapshotRealtime? _realtime;
  SnapshotRoom? _room;
  DriverLiveLocation? _location;
  double? _heading;
  Duration? _glide;
  var _loading = false;

  /// Last pushed leg for the current phase; null until the first push.
  List<MapLatLng>? _livePolyline;

  @override
  void initState() {
    super.initState();
    _sync();
  }

  @override
  void didUpdateWidget(LiveDriverMap oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.tracking != widget.tracking ||
        oldWidget.id != widget.id ||
        oldWidget.phase != widget.phase ||
        oldWidget.liveRouteTo?.lat != widget.liveRouteTo?.lat ||
        oldWidget.liveRouteTo?.lng != widget.liveRouteTo?.lng) {
      if (oldWidget.phase != widget.phase || oldWidget.id != widget.id) {
        _livePolyline = null;
      }
      _sync();
    }
  }

  void _sync() {
    _stopRealtime();
    if (!widget.tracking) {
      if (_location != null || _livePolyline != null) {
        setState(() {
          _location = null;
          _heading = null;
          _glide = null;
          _livePolyline = null;
        });
      }
      return;
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      unawaited(_snapshot());
      unawaited(_startRealtime());
    });
  }

  SnapshotRoom _roomFor() => widget.job == TrackedJob.ride
      ? RideLocationRoom(widget.id)
      : FoodLocationRoom(widget.id);

  Future<void> _startRealtime() async {
    if (!mounted || !widget.tracking) {
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
      return; // No socket wired: the REST snapshot is all we show.
    }
    final room = _roomFor();
    _realtime = realtime;
    _room = room;
    _pushSub = realtime.driverLocations.listen(_onPush);
    _routeSub = realtime.routeUpdates.listen(_onRoute);
    // After a reconnect the socket may have missed fixes: re-read REST once.
    _reconnectSub = realtime.reconnects.listen((_) => unawaited(_snapshot()));
    await realtime.connect(accessToken: auth.tokens.accessToken);
    await realtime.subscribe(room);
  }

  void _stopRealtime() {
    unawaited(_pushSub?.cancel());
    unawaited(_reconnectSub?.cancel());
    unawaited(_routeSub?.cancel());
    _routeSub = null;
    _pushSub = null;
    _reconnectSub = null;
    final realtime = _realtime;
    final room = _room;
    _realtime = null;
    _room = null;
    if (realtime != null && room != null) {
      unawaited(realtime.unsubscribe(room));
    }
  }

  void _onPush(DriverLocationHint hint) {
    final type = widget.job == TrackedJob.ride ? 'Ride' : 'FoodOrder';
    if (!mounted || !widget.tracking) {
      return;
    }
    if (hint.aggregateType != type || hint.aggregateId != widget.id) {
      return;
    }
    unawaited(
      _apply(
        DriverLiveLocation(lat: hint.lat, lng: hint.lng, at: hint.at),
        heading: hint.heading,
        speedMps: hint.speedMps,
      ),
    );
  }

  void _onRoute(RouteUpdateHint hint) {
    final type = widget.job == TrackedJob.ride ? 'Ride' : 'FoodOrder';
    if (!mounted || !widget.tracking) {
      return;
    }
    if (hint.aggregateType != type || hint.aggregateId != widget.id) {
      return;
    }
    final want = widget.phase == LiveRoutePhase.toPickup
        ? 'APPROACH'
        : widget.phase == LiveRoutePhase.toDropoff
        ? 'TRIP'
        : null;
    if (want == null || hint.phase != want) {
      return; // Stale leg from the previous phase.
    }
    setState(() {
      _livePolyline = hint.route.hasRoadPolyline ? hint.route.coords : const [];
    });
    widget.onRouteUpdate?.call(hint.route);
  }

  Future<void> _apply(
    DriverLiveLocation next, {
    double? heading,
    double? speedMps,
  }) async {
    final current = _location;
    if (current != null && next.at.isBefore(current.at)) {
      return; // Out-of-order push / late snapshot.
    }
    // Glide over ~the fix gap; rotate by reported course while moving, else
    // by movement bearing (null here → the map derives it from the glide).
    final glide = driverGlideDuration(current?.at, next.at);
    final rotate = driverMarkerHeading(
      deviceHeading: heading,
      speedMps: speedMps,
      movementBearing: current == null
          ? null
          : bearingDegrees(
              MapLatLng(lat: current.lat, lng: current.lng),
              MapLatLng(lat: next.lat, lng: next.lng),
            ),
    );
    setState(() {
      _location = next;
      _glide = glide;
      _heading = rotate ?? _heading;
    });
  }

  /// One authoritative REST read: on open and after socket reconnect only.
  Future<void> _snapshot() async {
    if (!mounted || _loading || !widget.tracking) {
      return;
    }
    final auth = context.read<AuthCubit>().state;
    if (auth is! AuthSignedIn) {
      return;
    }
    DriverLocationRepository repository;
    try {
      repository = context.read<DriverLocationRepository>();
    } on ProviderNotFoundException {
      return;
    }
    _loading = true;
    try {
      final next = await repository.latest(
        accessToken: auth.tokens.accessToken,
        job: widget.job,
        id: widget.id,
      );
      if (!mounted || !widget.tracking || next == null) {
        return;
      }
      await _apply(next);
    } catch (_) {
      // Keep the last fix; pushes continue to update it.
    } finally {
      _loading = false;
    }
  }

  @override
  void dispose() {
    _stopRealtime();
    super.dispose();
  }

  List<MapLatLng> _resolvedRoute(MapLatLng? driver) {
    final follow =
        widget.phase == LiveRoutePhase.toPickup ||
        widget.phase == LiveRoutePhase.toDropoff;
    if (follow) {
      final live = _livePolyline;
      if (live != null) {
        return live; // Pushed leg (empty ⇒ unavailable ⇒ no line).
      }
      final seed = widget.serverRoute;
      if (seed != null) {
        return seed.hasRoadPolyline ? seed.coords : const [];
      }
    }
    if (widget.roadFollowed && widget.route.length >= 2) {
      return widget.route;
    }
    if (widget.route.length >= 2) {
      if (driver == null || follow) {
        return widget.route;
      }
      // Approaching: keep booked path; driver is a separate marker.
      return widget.route;
    }
    // No road geometry: markers only, never a straight stop-to-stop line.
    return const [];
  }

  @override
  Widget build(BuildContext context) {
    final location = _location;
    final driver = location == null
        ? null
        : MapLatLng(lat: location.lat, lng: location.lng);
    final route = _resolvedRoute(driver);
    final map = LayoutBuilder(
      builder: (context, constraints) => context.read<MapPort>().buildMap(
        fitPadding: liveMapFitPadding(
          constraints.maxHeight,
          sheetFraction: widget.sheetFraction,
        ),
        center: widget.center,
        markers: widget.markers,
        driver: driver,
        route: route,
        pulseRoute: widget.pulseRoute && route.length >= 2,
        driverVehicle: widget.vehicle,
        firstMarkerIsPickup: widget.firstMarkerIsPickup,
        stopStyle: widget.job == TrackedJob.food
            ? MapStopStyle.food
            : MapStopStyle.ride,
        driverHeading: _heading,
        driverGlide: _glide,
      ),
    );
    if (location == null) {
      return map;
    }
    final local = location.at.toLocal();
    final time =
        '${local.hour.toString().padLeft(2, '0')}:'
        '${local.minute.toString().padLeft(2, '0')}';
    return Stack(
      fit: StackFit.expand,
      children: [
        map,
        Positioned(
          left: DealGoSpacing.s12,
          bottom: DealGoSpacing.s12,
          child: DecoratedBox(
            key: const Key('tracking-driver-live'),
            decoration: BoxDecoration(
              color: DealGoColors.card.withValues(alpha: 0.94),
              borderRadius: BorderRadius.circular(999),
              border: Border.all(color: DealGoColors.border),
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: DealGoSpacing.s8,
                vertical: DealGoSpacing.s4,
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    widget.vehicle == MapVehicleKind.motorbike
                        ? DealGoIcons.motorbike
                        : DealGoIcons.car,
                    size: 14,
                    color: DealGoColors.primary,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    AppLocalizations.of(context).trackingDriverLiveAt(time),
                    style: Theme.of(context).textTheme.labelSmall
                        ?.copyWith(fontWeight: FontWeight.w700),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// Camera padding that frames the route between the floating top bar and a
/// bottom sheet covering [sheetFraction] of a map [height] px tall.
EdgeInsets liveMapFitPadding(double height, {double sheetFraction = 0}) {
  if (!height.isFinite || height <= 0 || sheetFraction <= 0) {
    return const EdgeInsets.all(32);
  }
  final bottom = height * sheetFraction.clamp(0.0, 0.8) + 28;
  // Back button row (8 + 48) + bottom-anchored pin height (~44) + margin.
  const top = 112.0;
  // Keep at least ~120 px of framed map even on tiny screens.
  final room = height - bottom - top;
  return EdgeInsets.fromLTRB(
    40,
    top,
    40,
    room < 120 ? (height - top - 120).clamp(32.0, bottom) : bottom,
  );
}
