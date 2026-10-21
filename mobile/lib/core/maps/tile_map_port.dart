import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../design_system/icons/dealgo_icons.dart';
import '../design_system/tokens/dealgo_tokens.dart';
import 'map_lat_lng.dart';
import 'map_port.dart';

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
    );
  }
}

class TileMapView extends StatefulWidget {
  const TileMapView({
    required this.urlTemplate,
    required this.center,
    this.markers = const [],
    this.driver,
    this.attribution = '',
    this.tileProvider,
    super.key,
  });

  /// Assigned driver's live position (DEC-PROD-031).
  final MapLatLng? driver;

  final String urlTemplate;
  final String attribution;
  final TileProvider? tileProvider;
  final MapLatLng center;
  final List<MapLatLng> markers;

  @override
  State<TileMapView> createState() => _TileMapViewState();
}

class _TileMapViewState extends State<TileMapView> {
  static const _zoom = 15.0;
  final _controller = MapController();
  var _ready = false;

  static LatLng _ll(MapLatLng p) => LatLng(p.lat, p.lng);

  List<LatLng> get _points => [for (final m in widget.markers) _ll(m)];

  /// Points the camera must keep in view (stops plus the driver).
  List<LatLng> get _framed => [..._points, ?_driverPoint];

  LatLng? get _driverPoint {
    final driver = widget.driver;
    return driver == null ? null : _ll(driver);
  }

  CameraFit? _fit() {
    final points = _framed;
    if (points.length < 2) {
      return null;
    }
    return CameraFit.coordinates(
      coordinates: points,
      padding: const EdgeInsets.all(DealGoSpacing.s32),
      maxZoom: 17,
    );
  }

  @override
  void didUpdateWidget(TileMapView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!_ready) {
      return;
    }
    final moved =
        oldWidget.center.lat != widget.center.lat ||
        oldWidget.center.lng != widget.center.lng ||
        oldWidget.markers.length != widget.markers.length ||
        (oldWidget.driver == null) != (widget.driver == null);
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

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final points = _points;
    return FlutterMap(
      key: const Key('map-live'),
      mapController: _controller,
      options: MapOptions(
        initialCenter: _ll(widget.center),
        initialZoom: _zoom,
        initialCameraFit: _fit(),
        backgroundColor: const Color(0xFFE7EEF5),
        interactionOptions: const InteractionOptions(
          flags: InteractiveFlag.all & ~InteractiveFlag.rotate,
        ),
        onMapReady: () => _ready = true,
      ),
      children: [
        TileLayer(
          urlTemplate: widget.urlTemplate,
          userAgentPackageName: 'com.trancongtien.dealgo',
          tileProvider: widget.tileProvider,
          // Mapbox `@2x` raster tiles are 512px drawn at 256 logical.
          tileDimension: 256,
          retinaMode: widget.urlTemplate.contains('@2x'),
        ),
        MarkerLayer(
          markers: [
            for (var i = 0; i < points.length; i++)
              Marker(
                key: Key('map-live-marker-$i'),
                point: points[i],
                width: 36,
                height: 36,
                alignment: Alignment.topCenter,
                child: Icon(
                  DealGoIcons.pinFilled,
                  size: 36,
                  color: i == 0
                      ? DealGoColors.brandGreen
                      : DealGoColors.primary,
                ),
              ),
            if (_driverPoint case final driver?)
              Marker(
                key: const Key('map-live-driver'),
                point: driver,
                width: 34,
                height: 34,
                child: Container(
                  decoration: BoxDecoration(
                    color: DealGoColors.primary,
                    shape: BoxShape.circle,
                    border: Border.all(color: DealGoColors.card, width: 2),
                  ),
                  child: const Icon(
                    DealGoIcons.motorbike,
                    size: 18,
                    color: Colors.white,
                  ),
                ),
              ),
          ],
        ),
        if (widget.attribution.isNotEmpty)
          Align(
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
                widget.attribution,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 10),
              ),
            ),
          ),
      ],
    );
  }
}
