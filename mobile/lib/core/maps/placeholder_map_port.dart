import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../design_system/tokens/dealgo_tokens.dart';
import '../motion/dealgo_motion.dart';
import 'map_lat_lng.dart';
import 'map_markers.dart';
import 'map_port.dart';
import '../design_system/icons/dealgo_icons.dart';
import '../../l10n/app_localizations.dart';

/// Soft-fail map when `USE_MOCK_DATA` or no `MAPS_API_KEY`.
class PlaceholderMapPort implements MapPort {
  const PlaceholderMapPort();

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
    return PlaceholderMapView(
      key: key,
      center: center,
      markers: markers,
      driver: driver,
      route: route,
      pulseRoute: pulseRoute,
      driverVehicle: driverVehicle,
      firstMarkerIsPickup: firstMarkerIsPickup,
      stopStyle: stopStyle,
      // Placeholder paints in local canvas; fitPadding is accepted for MapPort parity.
    );
  }
}

/// Design-chrome map stub (no SDK). Matches mock overlay language, not live tiles.
class PlaceholderMapView extends StatefulWidget {
  const PlaceholderMapView({
    required this.center,
    this.markers = const [],
    this.route = const [],
    this.driver,
    this.pulseRoute = false,
    this.areaLabel,
    this.driverVehicle = MapVehicleKind.motorbike,
    this.firstMarkerIsPickup = true,
    this.stopStyle = MapStopStyle.ride,
    super.key,
  });

  final MapVehicleKind driverVehicle;
  final bool firstMarkerIsPickup;
  final MapStopStyle stopStyle;

  final MapLatLng center;
  final List<MapLatLng> markers;
  final List<MapLatLng> route;
  final bool pulseRoute;

  /// Live driver position; the stub only shows that one is known.
  final MapLatLng? driver;

  /// Optional caller-provided place name; the stub never invents one.
  final String? areaLabel;

  @override
  State<PlaceholderMapView> createState() => _PlaceholderMapViewState();
}

class _PlaceholderMapViewState extends State<PlaceholderMapView>
    with SingleTickerProviderStateMixin {
  AnimationController? _pulse;

  bool get _wantPulse =>
      widget.pulseRoute &&
      (widget.route.length >= 2 || widget.markers.length >= 2);

  void _syncPulse() {
    final reduced = DealGoMotion.prefersReducedMotion(context);
    // Infinite .repeat() breaks widget-test pumpAndSettle; keep static glow under
    // AutomatedTestWidgetsFlutterBinding (FLUTTER_TEST dart-define is not always set).
    final inWidgetTest = WidgetsBinding.instance.runtimeType
        .toString()
        .contains('TestWidgetsFlutterBinding');
    final animate =
        _wantPulse &&
        !reduced &&
        !inWidgetTest &&
        TickerMode.valuesOf(context).enabled;
    if (animate) {
      _pulse ??= AnimationController(vsync: this, duration: DealGoMotion.slow)
        ..repeat(reverse: true);
      return;
    }
    _pulse?.dispose();
    _pulse = null;
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _syncPulse();
  }

  @override
  void didUpdateWidget(PlaceholderMapView oldWidget) {
    super.didUpdateWidget(oldWidget);
    _syncPulse();
  }

  @override
  void dispose() {
    _pulse?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final pulse = _pulse;
    if (pulse == null) {
      return _layer(context, 0.5);
    }
    return AnimatedBuilder(
      animation: pulse,
      builder: (context, _) => _layer(context, pulse.value),
    );
  }

  Widget _layer(BuildContext context, double glowT) {
    final textTheme = Theme.of(context).textTheme;
    final l10n = AppLocalizations.of(context);
    final markers = widget.markers;
    final route = widget.route;
    final driver = widget.driver;
    final areaLabel = widget.areaLabel;
    return Semantics(
      label: [l10n.mapIllustrative, ?areaLabel].join(' · '),
      child: ColoredBox(
        key: const Key('map-placeholder'),
        color: const Color(0xFFE7EEF5),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final size = constraints.biggest;
            // With real coordinates, pins and the route sit where they really
            // are relative to each other (the road shape of the server route);
            // only the street grid behind them is illustrative.
            final project = PlaceholderProjection.fit([
              ...route,
              ...markers,
              ?driver,
            ], size);
            final routePoints = project == null || route.length < 2
                ? null
                : [for (final p in route) project(p)];
            Widget pin(
              Offset? at,
              Alignment fallback,
              Widget child, {
              Key? key,
            }) {
              if (at == null) {
                return Align(key: key, alignment: fallback, child: child);
              }
              const half = 18.0;
              return Positioned(
                key: key,
                left: at.dx - half,
                top: at.dy - half * 2,
                child: child,
              );
            }

            // Stop pins: the tip (bottom-center) sits on the projected point.
            Widget stop(Offset? at, Alignment fallback, Widget child) {
              if (at == null) {
                return Align(alignment: fallback, child: child);
              }
              final box = DealGoMapPin.boxFor(36);
              return Positioned(
                left: at.dx - box.width / 2,
                top: at.dy - box.height + 36 * 0.04,
                child: child,
              );
            }

            return Stack(
              fit: StackFit.expand,
              children: [
                CustomPaint(
                  painter: _StubMapPainter(
                    showRoute: route.length >= 2 || markers.length >= 2,
                    routePoints: routePoints,
                    pulseRoute: widget.pulseRoute,
                    pulseT: glowT,
                  ),
                ),
                if (route.length >= 2 || markers.length >= 2)
                  const IgnorePointer(
                    child: SizedBox.shrink(key: Key('map-placeholder-route')),
                  ),
                if (areaLabel case final area?)
                  Positioned(
                    left: DealGoSpacing.s12,
                    top: DealGoSpacing.s12,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        color: DealGoColors.card,
                        borderRadius: BorderRadius.circular(999),
                        border: Border.all(color: DealGoColors.border),
                        boxShadow: [
                          BoxShadow(
                            color: DealGoColors.text.withValues(alpha: 0.06),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: DealGoSpacing.s8,
                          vertical: DealGoSpacing.s4,
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              DealGoIcons.pinFilled,
                              color: DealGoColors.danger,
                              size: 14,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              area,
                              style: textTheme.labelSmall?.copyWith(
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                if (markers.isEmpty)
                  const Align(
                    alignment: Alignment(0, -0.05),
                    child: DealGoMapPin(
                      kind: DealGoMapPinKind.dropoff,
                      size: 36,
                    ),
                  )
                else ...[
                  stop(
                    project?.call(markers.first),
                    const Alignment(-0.25, -0.15),
                    DealGoMapPin(
                      kind: mapPinKindFor(
                        0,
                        firstMarkerIsPickup: widget.firstMarkerIsPickup,
                        style: widget.stopStyle,
                      ),
                      size: 36,
                    ),
                  ),
                  if (markers.length > 1)
                    stop(
                      // Multi-stop: the drop-off is the last marker.
                      project?.call(markers.last),
                      const Alignment(0.35, 0.35),
                      DealGoMapPin(
                        kind: mapPinKindFor(
                          1,
                          firstMarkerIsPickup: widget.firstMarkerIsPickup,
                          style: widget.stopStyle,
                        ),
                        size: 36,
                      ),
                    ),
                ],
                if (driver != null)
                  pin(
                    project?.call(driver),
                    const Alignment(0.05, 0.1),
                    DealGoDriverMarker(size: 36, vehicle: widget.driverVehicle),
                    key: const Key('map-placeholder-driver'),
                  ),
                Positioned(
                  right: DealGoSpacing.s12,
                  bottom: DealGoSpacing.s12,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: DealGoColors.card.withValues(alpha: 0.92),
                      borderRadius: BorderRadius.circular(999),
                      border: Border.all(color: DealGoColors.border),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: DealGoSpacing.s8,
                        vertical: DealGoSpacing.s4,
                      ),
                      child: Text(
                        l10n.mapIllustrative,
                        style: textTheme.labelSmall?.copyWith(
                          color: DealGoColors.textSecondary,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

/// Fits real coordinates into the placeholder box (equirectangular, north up,
/// aspect kept) so a server road route keeps its true shape.
class PlaceholderProjection {
  PlaceholderProjection._(this._toOffset);

  final Offset Function(MapLatLng) _toOffset;

  Offset call(MapLatLng point) => _toOffset(point);

  /// Null when there are fewer than two distinct points or no room to draw.
  static PlaceholderProjection? fit(
    List<MapLatLng> points,
    Size size, {
    double padding = 40,
  }) {
    if (points.length < 2 || !size.isFinite || size.isEmpty) {
      return null;
    }
    var minLat = points.first.lat, maxLat = points.first.lat;
    var minLng = points.first.lng, maxLng = points.first.lng;
    for (final p in points) {
      if (p.lat < minLat) minLat = p.lat;
      if (p.lat > maxLat) maxLat = p.lat;
      if (p.lng < minLng) minLng = p.lng;
      if (p.lng > maxLng) maxLng = p.lng;
    }
    final kx = math.cos((minLat + maxLat) / 2 * math.pi / 180);
    final spanX = (maxLng - minLng) * kx;
    final spanY = maxLat - minLat;
    if (spanX <= 0 && spanY <= 0) {
      return null;
    }
    final w = math.max(1.0, size.width - padding * 2);
    final h = math.max(1.0, size.height - padding * 2);
    final scale = math.min(
      spanX > 0 ? w / spanX : double.infinity,
      spanY > 0 ? h / spanY : double.infinity,
    );
    final offX = padding + (w - spanX * scale) / 2;
    final offY = padding + (h - spanY * scale) / 2;
    return PlaceholderProjection._(
      (p) => Offset(
        offX + (p.lng - minLng) * kx * scale,
        offY + (maxLat - p.lat) * scale,
      ),
    );
  }
}

class _StubMapPainter extends CustomPainter {
  const _StubMapPainter({
    this.showRoute = true,
    this.routePoints,
    this.pulseRoute = false,
    this.pulseT = 0.5,
  });

  final bool showRoute;

  /// Projected real route; null → the fixed illustrative curve.
  final List<Offset>? routePoints;
  final bool pulseRoute;
  final double pulseT;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(
      Offset.zero & size,
      Paint()..color = const Color(0xFFE7EEF5),
    );
    final street = Paint()
      ..color = const Color(0xFFF7F4EA)
      ..strokeWidth = 14
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(
      Offset(size.width * 0.05, size.height * 0.35),
      Offset(size.width * 0.95, size.height * 0.28),
      street,
    );
    canvas.drawLine(
      Offset(size.width * 0.2, size.height * 0.1),
      Offset(size.width * 0.55, size.height * 0.9),
      street,
    );
    canvas.drawLine(
      Offset(size.width * 0.65, size.height * 0.15),
      Offset(size.width * 0.85, size.height * 0.85),
      street,
    );
    if (!showRoute) {
      return;
    }
    final points = routePoints;
    final Path path;
    if (points != null && points.length >= 2) {
      path = Path()..moveTo(points.first.dx, points.first.dy);
      for (final p in points.skip(1)) {
        path.lineTo(p.dx, p.dy);
      }
    } else {
      path = Path()
        ..moveTo(size.width * 0.22, size.height * 0.55)
        ..quadraticBezierTo(
          size.width * 0.45,
          size.height * 0.2,
          size.width * 0.72,
          size.height * 0.62,
        );
    }
    if (pulseRoute) {
      final glowAlpha = 0.18 + (pulseT * 0.32);
      final glow = Paint()
        ..color = DealGoColors.primaryLight.withValues(alpha: glowAlpha)
        ..strokeWidth = 10 + (pulseT * 4)
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round;
      canvas.drawPath(path, glow);
    }
    final routePaint = Paint()
      ..color = DealGoColors.primary.withValues(alpha: 0.9)
      ..strokeWidth = 5
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    canvas.drawPath(path, routePaint);
  }

  @override
  bool shouldRepaint(covariant _StubMapPainter oldDelegate) =>
      oldDelegate.showRoute != showRoute ||
      oldDelegate.routePoints != routePoints ||
      oldDelegate.pulseRoute != pulseRoute ||
      oldDelegate.pulseT != pulseT;
}
