import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../design_system/tokens/dealgo_tokens.dart';
import '../motion/dealgo_motion.dart';
import 'map_lat_lng.dart';
import 'map_markers.dart';
import 'map_port.dart';
import 'map_style.dart';
import 'map_zoom.dart';

/// Live map over a configured raster XYZ tile source (flutter_map).
class TileMapPort implements MapPort {
  const TileMapPort({
    required this.urlTemplate,
    this.attribution = '',
    this.tileProvider,
  });

  final String urlTemplate;
  final String attribution;

  /// Test seam; production uses flutter_map's network provider.
  final TileProvider? tileProvider;

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
    return TileMapView(
      driver: driver,
      key: key,
      urlTemplate: urlTemplate,
      attribution: attribution,
      tileProvider: tileProvider,
      center: center,
      markers: markers,
      route: route,
      pulseRoute: pulseRoute,
      fitPadding: fitPadding,
      driverVehicle: driverVehicle,
      firstMarkerIsPickup: firstMarkerIsPickup,
      stopStyle: stopStyle,
      driverHeadingHint: driverHeading,
      driverGlide: driverGlide,
    );
  }
}

class TileMapView extends StatefulWidget {
  const TileMapView({
    required this.urlTemplate,
    required this.center,
    this.markers = const [],
    this.route = const [],
    this.driver,
    this.pulseRoute = false,
    this.fitPadding = const EdgeInsets.all(32),
    this.attribution = '',
    this.tileProvider,
    this.driverVehicle = MapVehicleKind.motorbike,
    this.firstMarkerIsPickup = true,
    this.stopStyle = MapStopStyle.ride,
    this.driverHeadingHint,
    this.driverGlide,
    super.key,
  });

  /// Reported heading (degrees from north) when the driver is moving.
  final double? driverHeadingHint;

  /// Marker glide time to the new fix; null = short default.
  final Duration? driverGlide;

  final MapVehicleKind driverVehicle;
  final bool firstMarkerIsPickup;
  final MapStopStyle stopStyle;

  /// Assigned driver's live position (DEC-PROD-031).
  final MapLatLng? driver;

  final String urlTemplate;
  final String attribution;
  final TileProvider? tileProvider;
  final MapLatLng center;
  final List<MapLatLng> markers;
  final List<MapLatLng> route;

  /// Soft glow under the route; animates when motion is allowed (reduced-motion → static).
  final bool pulseRoute;

  /// Keep markers/route inside the visible band (above sheet / below chips).
  final EdgeInsets fitPadding;

  @override
  State<TileMapView> createState() => _TileMapViewState();
}

class _TileMapViewState extends State<TileMapView>
    with TickerProviderStateMixin {
  static const _zoom = 15.0;
  final _controller = MapController();

  /// One provider for the map's lifetime. `TileLayer` builds a fresh
  /// `NetworkTileProvider` (own HTTP client) whenever none is passed, so the
  /// per-frame rebuilds of the route pulse / driver glide used to swap
  /// providers every frame and the tiles never finished loading (blank map
  /// behind a correct route on customer tracking). TileLayer disposes it.
  late final TileProvider _tileProvider =
      widget.tileProvider ?? NetworkTileProvider();
  var _ready = false;
  AnimationController? _pulse;
  AnimationController? _driverAnim;
  LatLng? _driverFrom;
  LatLng? _driverTo;
  LatLng? _driverDisplay;
  double? _heading;

  /// Driver heading in degrees: movement bearing, else first route segment.
  double get driverHeading =>
      widget.driverHeadingHint ??
      _heading ??
      (widget.driver != null
          ? bearingAlong([widget.driver!, ...widget.route.take(8)])
          : null) ??
      0;

  static LatLng _ll(MapLatLng p) => LatLng(p.lat, p.lng);

  List<LatLng> get _points => [for (final m in widget.markers) _ll(m)];

  List<LatLng> get _routePoints => [for (final p in widget.route) _ll(p)];

  /// Points the camera must keep in view (stops, route, driver).
  List<LatLng> get _framed => [..._points, ..._routePoints, ?_displayDriver];

  LatLng? get _driverPoint {
    final driver = widget.driver;
    return driver == null ? null : _ll(driver);
  }

  /// Animated driver position for smooth movement between polls.
  LatLng? get _displayDriver => _driverDisplay ?? _driverPoint;

  bool get _wantPulse => widget.pulseRoute && _routePoints.length >= 2;

  CameraFit? _fit() {
    final points = _framed;
    if (points.length < 2) {
      return null;
    }
    return CameraFit.coordinates(
      coordinates: points,
      padding: stopPinSafeFitPadding(widget.fitPadding, _pinSize),
      minZoom: kMapMinZoom,
      maxZoom: kMapFitMaxZoom,
    );
  }

  @override
  void initState() {
    super.initState();
    mapStyle.restore();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _syncPulse();
    if (_driverDisplay == null && widget.driver != null) {
      _driverDisplay = _ll(widget.driver!);
    }
  }

  @override
  void didUpdateWidget(TileMapView oldWidget) {
    super.didUpdateWidget(oldWidget);
    _syncPulse();
    _syncDriverAnim(oldWidget.driver);
    if (!_ready) {
      return;
    }
    final moved =
        oldWidget.center.lat != widget.center.lat ||
        oldWidget.center.lng != widget.center.lng ||
        oldWidget.markers.length != widget.markers.length ||
        oldWidget.route.length != widget.route.length ||
        oldWidget.fitPadding != widget.fitPadding ||
        (oldWidget.driver == null) != (widget.driver == null) ||
        (oldWidget.driver != null &&
            widget.driver != null &&
            (oldWidget.driver!.lat != widget.driver!.lat ||
                oldWidget.driver!.lng != widget.driver!.lng));
    if (!moved) {
      return;
    }
    final fit = _fit();
    if (fit != null) {
      _controller.fitCamera(fit);
    } else {
      _controller.move(_ll(widget.center), _controller.camera.zoom);
    }
  }

  void _syncDriverAnim(MapLatLng? previous) {
    final next = widget.driver;
    if (next == null) {
      _driverAnim?.dispose();
      _driverAnim = null;
      _driverFrom = null;
      _driverTo = null;
      _driverDisplay = null;
      return;
    }
    final to = _ll(next);
    if (previous == null) {
      _driverDisplay = to;
      _driverTo = to;
      return;
    }
    final from = _driverDisplay ?? _ll(previous);
    _heading =
        bearingDegrees(
          MapLatLng(lat: from.latitude, lng: from.longitude),
          next,
        ) ??
        _heading;
    if ((from.latitude - to.latitude).abs() < 1e-7 &&
        (from.longitude - to.longitude).abs() < 1e-7) {
      return;
    }
    final reduced = DealGoMotion.prefersReducedMotion(context);
    final inWidgetTest = WidgetsBinding.instance.runtimeType
        .toString()
        .contains('TestWidgetsFlutterBinding');
    if (reduced || inWidgetTest) {
      _driverDisplay = to;
      return;
    }
    _driverFrom = from;
    _driverTo = to;
    _driverAnim?.dispose();
    _driverAnim =
        AnimationController(
            vsync: this,
            duration: widget.driverGlide ?? const Duration(milliseconds: 450),
          )
          ..addListener(() {
            final a = _driverFrom;
            final b = _driverTo;
            final ctrl = _driverAnim;
            if (a == null || b == null || ctrl == null) {
              return;
            }
            // Linear when gliding across the whole fix gap (constant speed look).
            final t = widget.driverGlide == null
                ? Curves.easeOut.transform(ctrl.value)
                : ctrl.value;
            setState(() {
              _driverDisplay = LatLng(
                a.latitude + (b.latitude - a.latitude) * t,
                a.longitude + (b.longitude - a.longitude) * t,
              );
            });
          })
          ..forward();
  }

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
  void dispose() {
    _pulse?.dispose();
    _driverAnim?.dispose();
    _controller.dispose();
    super.dispose();
  }

  List<Polyline> _routePolylines(List<LatLng> route) {
    if (route.length < 2) {
      return const [];
    }
    final pulse = _pulse;
    final glowAlpha = pulse == null ? 0.35 : 0.18 + (pulse.value * 0.32);
    return [
      if (widget.pulseRoute)
        Polyline(
          points: route,
          strokeWidth: pulse == null ? 12 : 10 + (pulse.value * 4),
          color: DealGoColors.primaryLight.withValues(alpha: glowAlpha),
        ),
      Polyline(
        points: route,
        strokeWidth: 5,
        color: DealGoColors.primary.withValues(alpha: 0.9),
        borderStrokeWidth: 2,
        borderColor: DealGoColors.card.withValues(alpha: 0.9),
      ),
    ];
  }

  static const _pinSize = 42.0;

  Widget _buildMap() {
    final points = _points;
    final route = _routePoints;
    return FlutterMap(
      key: const Key('map-live'),
      mapController: _controller,
      options: MapOptions(
        initialCenter: _ll(widget.center),
        initialZoom: _zoom,
        minZoom: kMapMinZoom,
        maxZoom: kMapMaxZoom,
        initialCameraFit: _fit(),
        backgroundColor: const Color(0xFFE7EEF5),
        interactionOptions: const InteractionOptions(
          flags: InteractiveFlag.all & ~InteractiveFlag.rotate,
        ),
        onMapReady: () => _ready = true,
      ),
      children: [
        // Selected look (standard / satellite / dark) for every map; the
        // layer swaps its URL in place, the provider is kept.
        ValueListenableBuilder<DealGoMapStyle>(
          valueListenable: mapStyle,
          builder: (context, style, _) {
            final url = styledTileUrl(widget.urlTemplate, style);
            return TileLayer(
              urlTemplate: url,
              userAgentPackageName: 'dealgo.nguyengoctien.com',
              tileProvider: _tileProvider,
              // Mapbox `@2x` raster tiles are 512px drawn at 256 logical.
              tileDimension: 256,
              retinaMode: url.contains('@2x'),
            );
          },
        ),
        if (route.length >= 2)
          if (_pulse case final pulse?)
            // Only the route repaints per pulse frame, never the tiles.
            AnimatedBuilder(
              animation: pulse,
              builder: (context, _) => PolylineLayer(
                key: const Key('map-live-route'),
                polylines: _routePolylines(route),
              ),
            )
          else
            PolylineLayer(
              key: const Key('map-live-route'),
              polylines: _routePolylines(route),
            ),
        MarkerLayer(
          markers: [
            for (var i = 0; i < points.length; i++)
              Marker(
                key: Key('map-live-marker-$i'),
                point: points[i],
                width: DealGoMapPin.boxFor(_pinSize).width,
                height: DealGoMapPin.boxFor(_pinSize).height,
                // Pin tip sits exactly on the coordinate.
                alignment: DealGoMapPin.markerAlignment(_pinSize),
                child: DealGoMapPin(
                  size: _pinSize,
                  number: i,
                  kind: mapPinKindFor(
                    i,
                    firstMarkerIsPickup: widget.firstMarkerIsPickup,
                    style: widget.stopStyle,
                    count: points.length,
                  ),
                ),
              ),
            if (_displayDriver case final driver?)
              Marker(
                key: const Key('map-live-driver'),
                point: driver,
                width: 46,
                height: 46,
                child: DealGoDriverMarker(
                  key: Key('map-live-driver-${widget.driverVehicle.name}'),
                  size: 46,
                  vehicle: widget.driverVehicle,
                  heading: driverHeading,
                ),
              ),
          ],
        ),
        if (widget.attribution.isNotEmpty)
          ValueListenableBuilder<DealGoMapStyle>(
            valueListenable: mapStyle,
            builder: (context, style, _) => Align(
              alignment: Alignment.bottomRight,
              child: Container(
                key: const Key('map-live-attribution'),
                margin: const EdgeInsets.all(DealGoSpacing.s4),
                padding: const EdgeInsets.symmetric(
                  horizontal: DealGoSpacing.s4,
                  vertical: 2,
                ),
                color: const Color(0xCCFFFFFF),
                child: Text(
                  styledAttribution(
                    widget.attribution,
                    widget.urlTemplate,
                    style,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 10),
                ),
              ),
            ),
          ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) => _buildMap();
}

/// Fit padding that keeps a tip-anchored stop pin (teardrop + "Đón"/"Đến" chip)
/// fully inside the map: the whole marker box sits above its point, so the top
/// needs the box height and the sides half its width.
EdgeInsets stopPinSafeFitPadding(EdgeInsets requested, double pinSize) {
  final box = DealGoMapPin.boxFor(pinSize);
  final top = box.height + 8;
  final side = box.width / 2 + 6;
  return EdgeInsets.fromLTRB(
    requested.left < side ? side : requested.left,
    requested.top < top ? top : requested.top,
    requested.right < side ? side : requested.right,
    requested.bottom,
  );
}
