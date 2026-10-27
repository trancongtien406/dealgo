import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../l10n/app_localizations.dart';
import '../design_system/tokens/dealgo_tokens.dart';
import 'map_lat_lng.dart';

/// Stop role on DealGo maps: ride pickup (person, "Đón"), ride dropoff
/// (flag, "Đến"), food store (shop, "Quán") and food customer (home, "Giao").
enum DealGoMapPinKind { pickup, dropoff, store, home }

/// Which stop glyphs a map uses: ride (person → flag) or food (store → home).
enum MapStopStyle { ride, food }

/// Kind of stop [index] on a map (0 = first marker).
DealGoMapPinKind mapPinKindFor(
  int index, {
  required bool firstMarkerIsPickup,
  MapStopStyle style = MapStopStyle.ride,
}) {
  final first = index == 0 && firstMarkerIsPickup;
  return switch (style) {
    MapStopStyle.ride =>
      first ? DealGoMapPinKind.pickup : DealGoMapPinKind.dropoff,
    MapStopStyle.food => first ? DealGoMapPinKind.store : DealGoMapPinKind.home,
  };
}

/// Top-down vehicle drawn for the live driver / shipper.
enum MapVehicleKind { motorbike, car4, car7 }

/// Maps a Ride `vehicleClassCode` to the map vehicle. Unknown / empty → motorbike
/// (Food shippers are always motorbike). Purely visual — eligibility stays
/// fail-closed on the backend.
MapVehicleKind mapVehicleForClass(String? code) {
  final c = (code ?? '').trim().toUpperCase();
  if (c == 'CAR_7' || c.startsWith('CAR_7') || c == 'SUV') {
    return MapVehicleKind.car7;
  }
  if (c.startsWith('CAR')) {
    return MapVehicleKind.car4;
  }
  return MapVehicleKind.motorbike;
}

/// Initial bearing (degrees, 0 = north, clockwise) from [from] to [to].
/// Returns null when the points are (almost) identical so callers keep the
/// previous heading instead of snapping north.
double? bearingDegrees(MapLatLng from, MapLatLng to) {
  final dLat = (to.lat - from.lat).abs();
  final dLng = (to.lng - from.lng).abs();
  if (dLat < 1e-6 && dLng < 1e-6) {
    return null;
  }
  final lat1 = from.lat * math.pi / 180;
  final lat2 = to.lat * math.pi / 180;
  final dl = (to.lng - from.lng) * math.pi / 180;
  final y = math.sin(dl) * math.cos(lat2);
  final x =
      math.cos(lat1) * math.sin(lat2) -
      math.sin(lat1) * math.cos(lat2) * math.cos(dl);
  final deg = math.atan2(y, x) * 180 / math.pi;
  return (deg + 360) % 360;
}

/// Heading along a polyline at its first segment (used before any movement).
double? bearingAlong(List<MapLatLng> path) {
  for (var i = 0; i + 1 < path.length; i++) {
    final b = bearingDegrees(path[i], path[i + 1]);
    if (b != null) {
      return b;
    }
  }
  return null;
}

bool _inWidgetTest() => WidgetsBinding.instance.runtimeType.toString().contains(
  'TestWidgetsFlutterBinding',
);

/// Stop marker: a teardrop pin with a glyph (person / flag / store /
/// home) under a short label chip ("Đón" / "Đến" / "Quán" / "Giao"), with a
/// ground shadow. Vector-painted, so it is sharp at any device pixel ratio.
///
/// The pin tip is at the bottom-center of the box: place it with
/// [markerAlignment] (flutter_map) so the tip sits on the coordinate.
class DealGoMapPin extends StatelessWidget {
  const DealGoMapPin({
    required this.kind,
    this.size = 44,
    this.showLabel = true,
    super.key,
  });

  final DealGoMapPinKind kind;

  /// Pin height; the box adds the label chip above it.
  final double size;
  final bool showLabel;

  static const _tip = 0.96;
  static const _chipFactor = 0.46;
  static const _gapFactor = 0.06;

  /// Marker box for a pin of [size] (chip + pin).
  static Size boxFor(double size, {bool showLabel = true}) => Size(
    size * 1.7,
    showLabel ? size * (1 + _chipFactor + _gapFactor) : size,
  );

  /// flutter_map `Marker.alignment` that puts the tip on the point.
  static Alignment markerAlignment(double size, {bool showLabel = true}) {
    final h = boxFor(size, showLabel: showLabel).height;
    final tipY = h - size * (1 - _tip);
    return Alignment(0, -(2 * tipY / h - 1));
  }

  static Color colorOf(DealGoMapPinKind kind) => switch (kind) {
    DealGoMapPinKind.pickup => DealGoColors.brandGreen,
    DealGoMapPinKind.dropoff => DealGoColors.danger,
    DealGoMapPinKind.store => DealGoColors.amber,
    DealGoMapPinKind.home => DealGoColors.primary,
  };

  static IconData glyphOf(DealGoMapPinKind kind) => switch (kind) {
    DealGoMapPinKind.pickup => Icons.person_rounded,
    DealGoMapPinKind.dropoff => Icons.flag_rounded,
    DealGoMapPinKind.store => Icons.storefront_rounded,
    DealGoMapPinKind.home => Icons.home_rounded,
  };

  String _label(BuildContext context) {
    final l10n = Localizations.of<AppLocalizations>(context, AppLocalizations);
    return switch (kind) {
      DealGoMapPinKind.pickup => l10n?.mapPinPickup ?? 'Đón',
      DealGoMapPinKind.dropoff => l10n?.mapPinDropoff ?? 'Đến',
      DealGoMapPinKind.store => l10n?.mapPinStore ?? 'Quán',
      DealGoMapPinKind.home => l10n?.mapPinHome ?? 'Giao',
    };
  }

  @override
  Widget build(BuildContext context) {
    final color = colorOf(kind);
    final box = boxFor(size, showLabel: showLabel);
    final pinW = size * 0.8;
    final headR = pinW * 0.44;
    final pin = SizedBox(
      key: Key('map-pin-${kind.name}'),
      width: pinW,
      height: size,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned.fill(
            child: CustomPaint(
              painter: StopPinPainter(color: color, tipFraction: _tip),
            ),
          ),
          Positioned(
            left: pinW / 2 - headR,
            top: 1.5,
            width: headR * 2,
            height: headR * 2,
            child: Center(
              child: Icon(
                glyphOf(kind),
                size: headR * 1.15,
                color: Colors.white,
              ),
            ),
          ),
        ],
      ),
    );
    return SizedBox(
      width: box.width,
      height: box.height,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          if (showLabel) ...[
            SizedBox(
              height: size * _chipFactor,
              child: _PinChip(label: _label(context), color: color, size: size),
            ),
            SizedBox(height: size * _gapFactor),
          ],
          pin,
        ],
      ),
    );
  }
}

class _PinChip extends StatelessWidget {
  const _PinChip({
    required this.label,
    required this.color,
    required this.size,
  });

  final String label;
  final Color color;
  final double size;

  @override
  Widget build(BuildContext context) => Center(
    child: Container(
      padding: EdgeInsets.symmetric(
        horizontal: size * 0.2,
        vertical: size * 0.04,
      ),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Colors.white, width: 1.5),
        boxShadow: const [
          BoxShadow(
            color: Color(0x33000000),
            blurRadius: 4,
            offset: Offset(0, 1),
          ),
        ],
      ),
      child: Text(
        label,
        maxLines: 1,
        textScaler: TextScaler.noScaling,
        style: TextStyle(
          color: Colors.white,
          fontSize: size * 0.26,
          fontWeight: FontWeight.w800,
          height: 1.15,
          letterSpacing: 0.2,
        ),
      ),
    ),
  );
}

/// Teardrop pin body: ground shadow at the tip, soft drop shadow, white rim,
/// colored fill with a subtle top highlight. Tip at [tipFraction] of height.
class StopPinPainter extends CustomPainter {
  const StopPinPainter({required this.color, this.tipFraction = 0.96});

  final Color color;
  final double tipFraction;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final cx = w / 2;
    final r = w * 0.44;
    final cy = r + 1.5;
    final tipY = h * tipFraction;

    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(cx, tipY),
        width: w * 0.42,
        height: h * 0.08,
      ),
      Paint()
        ..color = const Color(0x55000000)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 1.8),
    );

    Path tear(double grow) {
      final rr = r + grow;
      final tip = tipY + grow * 1.4;
      final d = tip - cy;
      final a = math.asin((rr / d).clamp(0.0, 0.999));
      final tx = rr * math.cos(a);
      final ty = rr * math.sin(a);
      return Path()
        ..moveTo(cx, tip)
        ..lineTo(cx - tx, cy + ty)
        ..lineTo(cx + tx, cy + ty)
        ..close();
    }

    void shape(double grow, Paint paint) {
      canvas.drawCircle(Offset(cx, cy), r + grow, paint);
      canvas.drawPath(tear(grow), paint);
    }

    canvas.save();
    canvas.translate(0, 1.6);
    shape(
      1,
      Paint()
        ..color = const Color(0x40000000)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2.4),
    );
    canvas.restore();
    shape(0, Paint()..color = Colors.white);
    shape(-2.2, Paint()..color = color);
    // Top highlight for a bit of depth.
    canvas.drawCircle(
      Offset(cx - r * 0.25, cy - r * 0.3),
      r * 0.5,
      Paint()
        ..color = Colors.white.withValues(alpha: 0.14)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3),
    );
  }

  @override
  bool shouldRepaint(covariant StopPinPainter old) =>
      old.color != color || old.tipFraction != tipFraction;
}

/// Customer pickup: white-ringed green dot with a soft pulsing halo.
class DealGoPickupDot extends StatefulWidget {
  const DealGoPickupDot({this.size = 44, this.animate = true, super.key});

  final double size;
  final bool animate;

  @override
  State<DealGoPickupDot> createState() => _DealGoPickupDotState();
}

class _DealGoPickupDotState extends State<DealGoPickupDot>
    with SingleTickerProviderStateMixin {
  AnimationController? _ctrl;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final reduced = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
    final run = widget.animate && !reduced && !_inWidgetTest();
    if (run) {
      _ctrl ??= AnimationController(
        vsync: this,
        duration: const Duration(milliseconds: 1800),
      )..repeat();
    } else {
      _ctrl?.dispose();
      _ctrl = null;
    }
  }

  @override
  void dispose() {
    _ctrl?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ctrl = _ctrl;
    Widget paint(double t) => CustomPaint(
      size: Size.square(widget.size),
      painter: PickupDotPainter(color: DealGoColors.brandGreen, pulse: t),
    );
    return SizedBox.square(
      dimension: widget.size,
      child: ctrl == null
          ? paint(0.35)
          : AnimatedBuilder(
              animation: ctrl,
              builder: (_, _) => paint(ctrl.value),
            ),
    );
  }
}

class PickupDotPainter extends CustomPainter {
  const PickupDotPainter({required this.color, this.pulse = 0.35});

  final Color color;

  /// 0..1 halo phase.
  final double pulse;

  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    final maxR = size.shortestSide / 2;
    final dotR = maxR * 0.34;
    // Static soft halo.
    canvas.drawCircle(
      c,
      maxR * 0.62,
      Paint()..color = color.withValues(alpha: 0.16),
    );
    // Expanding pulse ring.
    final pr = dotR + (maxR - dotR) * pulse;
    canvas.drawCircle(
      c,
      pr,
      Paint()..color = color.withValues(alpha: 0.28 * (1 - pulse)),
    );
    // Shadow.
    canvas.drawCircle(
      c.translate(0, 1.2),
      dotR + 2.6,
      Paint()
        ..color = const Color(0x40000000)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2),
    );
    canvas.drawCircle(c, dotR + 2.6, Paint()..color = Colors.white);
    canvas.drawCircle(c, dotR, Paint()..color = color);
  }

  @override
  bool shouldRepaint(covariant PickupDotPainter old) =>
      old.pulse != pulse || old.color != color;
}

/// Destination: compact teardrop pin with white core (no letter). Tip is at the
/// bottom-center of the box — align markers with `Alignment.topCenter` so the
/// tip sits on the coordinate.
class DealGoDropoffPin extends StatelessWidget {
  const DealGoDropoffPin({this.size = 44, super.key});

  final double size;

  @override
  Widget build(BuildContext context) => SizedBox(
    width: size * 0.78,
    height: size,
    child: CustomPaint(painter: DropoffPinPainter(color: DealGoColors.primary)),
  );
}

class DropoffPinPainter extends CustomPainter {
  const DropoffPinPainter({required this.color});

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final cx = w / 2;
    final r = w * 0.42;
    final cy = r + 1.5;
    final tipY = h * 0.86;

    // Ground shadow ellipse at the tip.
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(cx, tipY + 1),
        width: w * 0.38,
        height: h * 0.09,
      ),
      Paint()
        ..color = const Color(0x44000000)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 1.6),
    );

    // Teardrop = circle + tangent triangle (drawn separately; avoids arc
    // edge cases on Impeller).
    Path tear(double grow) {
      final rr = r + grow;
      final d = (tipY + grow * 1.4) - cy;
      final a = math.asin((rr / d).clamp(0.0, 0.999));
      final tx = rr * math.cos(a);
      final ty = rr * math.sin(a);
      return Path()
        ..moveTo(cx, tipY + grow * 1.4)
        ..lineTo(cx - tx, cy + ty)
        ..lineTo(cx + tx, cy + ty)
        ..close();
    }

    void shape(double grow, Paint paint) {
      canvas.drawCircle(Offset(cx, cy), r + grow, paint);
      canvas.drawPath(tear(grow), paint);
    }

    canvas.save();
    canvas.translate(0, 1.2);
    shape(
      1,
      Paint()
        ..color = const Color(0x38000000)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2),
    );
    canvas.restore();
    shape(0, Paint()..color = Colors.white);
    shape(-2, Paint()..color = color);
    canvas.drawCircle(Offset(cx, cy), r * 0.40, Paint()..color = Colors.white);
  }

  @override
  bool shouldRepaint(covariant DropoffPinPainter old) => old.color != color;
}

/// Live driver / shipper: top-down vehicle rotated to [heading] (deg, 0 = north).
class DealGoDriverMarker extends StatelessWidget {
  const DealGoDriverMarker({
    this.size = 44,
    this.vehicle = MapVehicleKind.motorbike,
    this.heading = 0,
    super.key,
  });

  final double size;
  final MapVehicleKind vehicle;
  final double heading;

  @override
  Widget build(BuildContext context) => SizedBox.square(
    dimension: size,
    child: Transform.rotate(
      angle: heading * math.pi / 180,
      child: CustomPaint(painter: TopDownVehiclePainter(vehicle: vehicle)),
    ),
  );
}

/// Draws a vehicle seen from above, nose pointing up.
class TopDownVehiclePainter extends CustomPainter {
  const TopDownVehiclePainter({required this.vehicle});

  final MapVehicleKind vehicle;

  static const _body = DealGoColors.primary;
  static const _glass = Color(0xFF1E2A3A);

  @override
  void paint(Canvas canvas, Size size) {
    switch (vehicle) {
      case MapVehicleKind.motorbike:
        _bike(canvas, size);
      case MapVehicleKind.car4:
        _car(canvas, size, lengthFactor: 0.82);
      case MapVehicleKind.car7:
        _car(canvas, size, lengthFactor: 0.94);
    }
  }

  void _shadow(Canvas canvas, RRect r) {
    canvas.drawRRect(
      r.shift(const Offset(0, 1.5)),
      Paint()
        ..color = const Color(0x55000000)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2.5),
    );
  }

  void _car(Canvas canvas, Size s, {required double lengthFactor}) {
    final c = s.center(Offset.zero);
    final h = s.height * lengthFactor;
    final w = h * 0.47;
    final body = RRect.fromRectAndRadius(
      Rect.fromCenter(center: c, width: w, height: h),
      Radius.circular(w * 0.34),
    );
    _shadow(canvas, body);
    // Wheels peeking out.
    final wheel = Paint()..color = const Color(0xFF111111);
    for (final dy in [-h * 0.30, h * 0.30]) {
      for (final dx in [-w / 2, w / 2]) {
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromCenter(
              center: c.translate(dx, dy),
              width: w * 0.16,
              height: h * 0.16,
            ),
            const Radius.circular(1.5),
          ),
          wheel,
        );
      }
    }
    canvas.drawRRect(body, Paint()..color = _body);
    canvas.drawRRect(
      body,
      Paint()
        ..color = Colors.white
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.6,
    );
    final top = c.dy - h / 2;
    // Windshield (front).
    final ws = Path()
      ..moveTo(c.dx - w * 0.36, top + h * 0.30)
      ..quadraticBezierTo(c.dx, top + h * 0.20, c.dx + w * 0.36, top + h * 0.30)
      ..lineTo(c.dx + w * 0.30, top + h * 0.42)
      ..lineTo(c.dx - w * 0.30, top + h * 0.42)
      ..close();
    canvas.drawPath(ws, Paint()..color = _glass);
    // Roof highlight.
    final roofLen = vehicle == MapVehicleKind.car7 ? 0.32 : 0.24;
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(c.dx - w * 0.30, top + h * 0.44, w * 0.60, h * roofLen),
        Radius.circular(w * 0.10),
      ),
      Paint()..color = Colors.white.withValues(alpha: 0.18),
    );
    // Rear window.
    final rwTop = top + h * (0.46 + roofLen);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(c.dx - w * 0.30, rwTop, w * 0.60, h * 0.10),
        Radius.circular(w * 0.08),
      ),
      Paint()..color = _glass,
    );
    // Headlights.
    final hl = Paint()..color = const Color(0xFFFFF4C2);
    canvas.drawCircle(Offset(c.dx - w * 0.28, top + h * 0.06), w * 0.07, hl);
    canvas.drawCircle(Offset(c.dx + w * 0.28, top + h * 0.06), w * 0.07, hl);
  }

  void _bike(Canvas canvas, Size s) {
    final c = s.center(Offset.zero);
    final h = s.height * 0.80;
    final top = c.dy - h / 2;
    final tyre = Paint()..color = const Color(0xFF111111);
    // Front & rear tyres.
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(
          center: Offset(c.dx, top + h * 0.09),
          width: h * 0.11,
          height: h * 0.20,
        ),
        Radius.circular(h * 0.05),
      ),
      tyre,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(
          center: Offset(c.dx, top + h * 0.90),
          width: h * 0.13,
          height: h * 0.20,
        ),
        Radius.circular(h * 0.06),
      ),
      tyre,
    );
    // Body (scooter deck).
    final body = RRect.fromRectAndRadius(
      Rect.fromCenter(
        center: c.translate(0, h * 0.06),
        width: h * 0.26,
        height: h * 0.62,
      ),
      Radius.circular(h * 0.13),
    );
    _shadow(canvas, body);
    canvas.drawRRect(body, Paint()..color = _body);
    canvas.drawRRect(
      body,
      Paint()
        ..color = Colors.white
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.4,
    );
    // Handlebar.
    canvas.drawLine(
      Offset(c.dx - h * 0.24, top + h * 0.22),
      Offset(c.dx + h * 0.24, top + h * 0.22),
      Paint()
        ..color = const Color(0xFF222222)
        ..strokeWidth = h * 0.05
        ..strokeCap = StrokeCap.round,
    );
    // Rider shoulders + helmet.
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(c.dx, top + h * 0.40),
        width: h * 0.42,
        height: h * 0.18,
      ),
      Paint()..color = const Color(0xFF2B3440),
    );
    canvas.drawCircle(
      Offset(c.dx, top + h * 0.37),
      h * 0.12,
      Paint()..color = DealGoColors.brandGreen,
    );
    canvas.drawCircle(
      Offset(c.dx, top + h * 0.37),
      h * 0.12,
      Paint()
        ..color = Colors.white
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.3,
    );
    // Headlight.
    canvas.drawCircle(
      Offset(c.dx, top + h * 0.02),
      h * 0.035,
      Paint()..color = const Color(0xFFFFF4C2),
    );
  }

  @override
  bool shouldRepaint(covariant TopDownVehiclePainter old) =>
      old.vehicle != vehicle;
}

/// DEC-PROD-031 rev 2026-10-24: marker heading. The device GPS course is used
/// only while actually moving (GPS course is noise when stationary); otherwise
/// the bearing between the last two fixes. [minSpeedMps] is a DRAFT threshold.
double? driverMarkerHeading({
  double? deviceHeading,
  double? speedMps,
  double? movementBearing,
  double minSpeedMps = 1.5,
}) {
  if (deviceHeading != null &&
      deviceHeading.isFinite &&
      speedMps != null &&
      speedMps >= minSpeedMps) {
    return deviceHeading % 360;
  }
  return movementBearing;
}

/// How long to glide the marker from the previous fix to the next one: about
/// the gap between fixes (so it keeps moving until the next one lands, as
/// suggested by Gojek's live-tracking write-up), clamped to [min]..[max].
Duration driverGlideDuration(
  DateTime? previousAt,
  DateTime nextAt, {
  Duration min = const Duration(milliseconds: 450),
  Duration max = const Duration(seconds: 6),
}) {
  if (previousAt == null) {
    return min;
  }
  final gap = nextAt.difference(previousAt);
  if (gap <= min) {
    return min;
  }
  return gap >= max ? max : gap;
}
