import 'package:flutter/material.dart';

import '../design_system/tokens/dealgo_tokens.dart';
import 'map_lat_lng.dart';
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
    Key? key,
  }) {
    return PlaceholderMapView(
      key: key,
      center: center,
      markers: markers,
      driver: driver,
    );
  }
}

/// Design-chrome map stub (no SDK). Matches mock overlay language, not live tiles.
class PlaceholderMapView extends StatelessWidget {
  const PlaceholderMapView({
    required this.center,
    this.markers = const [],
    this.driver,
    this.areaLabel,
    super.key,
  });

  final MapLatLng center;
  final List<MapLatLng> markers;

  /// Live driver position; the stub only shows that one is known.
  final MapLatLng? driver;

  /// Optional caller-provided place name; the stub never invents one.
  final String? areaLabel;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final l10n = AppLocalizations.of(context);
    return Semantics(
      label: [l10n.mapIllustrative, ?areaLabel].join(' · '),
      child: ColoredBox(
        key: const Key('map-placeholder'),
        color: const Color(0xFFE7EEF5),
        child: Stack(
          fit: StackFit.expand,
          children: [
            const CustomPaint(painter: _StubMapPainter()),
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
                child: _MapPin(color: DealGoColors.primary),
              )
            else ...[
              const Align(
                alignment: Alignment(-0.25, -0.15),
                child: _MapPin(color: DealGoColors.brandGreen),
              ),
              if (markers.length > 1)
                const Align(
                  alignment: Alignment(0.35, 0.35),
                  child: _MapPin(color: DealGoColors.danger),
                ),
            ],
            if (driver != null)
              const Align(
                key: Key('map-placeholder-driver'),
                alignment: Alignment(0.05, 0.1),
                child: _DriverBadge(),
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
        ),
      ),
    );
  }
}

class _DriverBadge extends StatelessWidget {
  const _DriverBadge();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 30,
      height: 30,
      decoration: BoxDecoration(
        color: DealGoColors.primary,
        shape: BoxShape.circle,
        border: Border.all(color: DealGoColors.card, width: 2),
      ),
      child: const Icon(DealGoIcons.motorbike, size: 16, color: Colors.white),
    );
  }
}

class _MapPin extends StatelessWidget {
  const _MapPin({required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: DealGoColors.card,
        shape: BoxShape.circle,
        border: Border.all(color: DealGoColors.border),
        boxShadow: [
          BoxShadow(
            color: DealGoColors.text.withValues(alpha: 0.1),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: SizedBox(
        width: 28,
        height: 28,
        child: Icon(DealGoIcons.circle, color: color, size: 12),
      ),
    );
  }
}

class _StubMapPainter extends CustomPainter {
  const _StubMapPainter();

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
    final route = Paint()
      ..color = DealGoColors.primary
      ..strokeWidth = 5
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    final path = Path()
      ..moveTo(size.width * 0.22, size.height * 0.55)
      ..quadraticBezierTo(
        size.width * 0.45,
        size.height * 0.2,
        size.width * 0.72,
        size.height * 0.62,
      );
    canvas.drawPath(path, route);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
