import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../design_system/tokens/dealgo_tokens.dart';
import 'map_lat_lng.dart';
import 'map_port.dart';
import 'map_style.dart';
import 'map_zoom.dart';
import 'tile_map_port.dart';

/// Moves the camera of a [PinPickerMap] (search result, my location).
class PinPickerController {
  void Function(MapLatLng target, double? zoom)? _move;
  void Function(double delta)? _zoomBy;

  void moveTo(MapLatLng target, {double? zoom}) => _move?.call(target, zoom);

  void zoomBy(double delta) => _zoomBy?.call(delta);
}

/// Map for pick-on-map: the camera moves under a fixed centre pin and every
/// camera change reports the new centre. Live tiles use the same template,
/// tile size and selected look as the other maps, so tiles already loaded are
/// served from the image cache; without a tile source a pannable stub keeps
/// the flow usable.
class PinPickerMap extends StatefulWidget {
  const PinPickerMap({
    required this.port,
    required this.initialCenter,
    required this.controller,
    required this.onCenterChanged,
    this.initialZoom = 16,
    this.tileProvider,
    super.key,
  });

  final MapPort port;
  final MapLatLng initialCenter;
  final PinPickerController controller;
  final ValueChanged<MapLatLng> onCenterChanged;
  final double initialZoom;

  /// Test seam; production uses flutter_map's network provider.
  final TileProvider? tileProvider;

  @override
  State<PinPickerMap> createState() => _PinPickerMapState();
}

class _PinPickerMapState extends State<PinPickerMap> {
  final _map = MapController();
  var _ready = false;
  (MapLatLng, double?)? _pending;
  late MapLatLng _stubCenter = widget.initialCenter;
  late double _stubZoom = widget.initialZoom;

  /// One provider for the picker's lifetime (TileLayer disposes it). Tile
  /// images are keyed by URL in Flutter's image cache, so the tiles the ride
  /// map already loaded are not fetched again.
  late final TileProvider _tiles =
      widget.tileProvider ??
      (widget.port is TileMapPort
          ? (widget.port as TileMapPort).tileProvider
          : null) ??
      NetworkTileProvider();

  @override
  void initState() {
    super.initState();
    mapStyle.restore();
    widget.controller
      .._move = _moveTo
      .._zoomBy = _zoomBy;
  }

  @override
  void dispose() {
    widget.controller
      .._move = null
      .._zoomBy = null;
    _map.dispose();
    super.dispose();
  }

  void _moveTo(MapLatLng target, double? zoom) {
    if (widget.port is TileMapPort) {
      if (_ready) {
        _map.move(LatLng(target.lat, target.lng), clampMapZoom(zoom ?? _map.camera.zoom));
      } else {
        _pending = (target, zoom);
      }
      return;
    }
    setState(() {
      _stubCenter = target;
      _stubZoom = zoom ?? _stubZoom;
    });
    widget.onCenterChanged(target);
  }

  void _zoomBy(double delta) {
    if (widget.port is TileMapPort) {
      if (_ready) {
        final camera = _map.camera;
        _map.move(camera.center, clampMapZoom(camera.zoom + delta));
      }
      return;
    }
    setState(() => _stubZoom = (_stubZoom + delta).clamp(3, 19));
  }

  @override
  Widget build(BuildContext context) {
    final port = widget.port;
    if (port is TileMapPort) {
      return _live(port);
    }
    return _stub();
  }

  Widget _live(TileMapPort port) {
    return ValueListenableBuilder<DealGoMapStyle>(
      valueListenable: mapStyle,
      builder: (context, style, _) {
        final url = styledTileUrl(port.urlTemplate, style);
        final attribution = styledAttribution(
          port.attribution,
          port.urlTemplate,
          style,
        );
        return FlutterMap(
          key: const Key('picker-map-live'),
          mapController: _map,
          options: MapOptions(
            initialCenter: LatLng(
              widget.initialCenter.lat,
              widget.initialCenter.lng,
            ),
            initialZoom: clampMapZoom(widget.initialZoom),
            minZoom: kMapMinZoom,
            maxZoom: kMapMaxZoom,
            backgroundColor: style == DealGoMapStyle.dark
                ? const Color(0xFF1F2430)
                : const Color(0xFFE7EEF5),
            interactionOptions: const InteractionOptions(
              flags: InteractiveFlag.all & ~InteractiveFlag.rotate,
            ),
            onMapReady: () {
              _ready = true;
              if (_pending case (final target, final zoom)) {
                _pending = null;
                _moveTo(target, zoom);
              }
            },
            onPositionChanged: (camera, _) => widget.onCenterChanged(
              MapLatLng(
                lat: camera.center.latitude,
                lng: camera.center.longitude,
              ),
            ),
          ),
          children: [
            TileLayer(
              urlTemplate: url,
              userAgentPackageName: 'dealgo.nguyengoctien.com',
              tileProvider: _tiles,
              tileDimension: 256,
              retinaMode: url.contains('@2x'),
            ),
            if (attribution.isNotEmpty)
              Align(
                alignment: Alignment.bottomRight,
                child: Container(
                  key: const Key('picker-map-attribution'),
                  margin: const EdgeInsets.all(DealGoSpacing.s4),
                  padding: const EdgeInsets.symmetric(
                    horizontal: DealGoSpacing.s4,
                    vertical: 2,
                  ),
                  color: const Color(0xCCFFFFFF),
                  child: Text(
                    attribution,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 10),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }

  /// Degrees per logical pixel at [_stubZoom] (Web Mercator, 256px tiles).
  double get _degPerPx => 360 / (256 * math.pow(2, _stubZoom));

  Widget _stub() {
    return GestureDetector(
      key: const Key('picker-map-placeholder'),
      behavior: HitTestBehavior.opaque,
      onDoubleTap: () => _zoomBy(1),
      onPanUpdate: (details) {
        final deg = _degPerPx;
        final latScale = math.cos(_stubCenter.lat * math.pi / 180);
        final next = MapLatLng(
          lat: (_stubCenter.lat + details.delta.dy * deg * latScale).clamp(
            -85,
            85,
          ),
          lng: _stubCenter.lng - details.delta.dx * deg,
        );
        setState(() => _stubCenter = next);
        widget.onCenterChanged(next);
      },
      child: CustomPaint(
        painter: _StubGridPainter(
          offset: Offset(
            _stubCenter.lng / _degPerPx,
            -_stubCenter.lat / _degPerPx,
          ),
        ),
        child: const SizedBox.expand(),
      ),
    );
  }
}

class _StubGridPainter extends CustomPainter {
  const _StubGridPainter({required this.offset});

  final Offset offset;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(
      Offset.zero & size,
      Paint()..color = const Color(0xFFE7EEF5),
    );
    final road = Paint()
      ..color = const Color(0xFFFFFFFF)
      ..strokeWidth = 6;
    const step = 90.0;
    final dx = -(offset.dx % step);
    final dy = -(offset.dy % step);
    for (var x = dx; x < size.width; x += step) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), road);
    }
    for (var y = dy; y < size.height; y += step) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), road);
    }
  }

  @override
  bool shouldRepaint(_StubGridPainter old) => old.offset != offset;
}
