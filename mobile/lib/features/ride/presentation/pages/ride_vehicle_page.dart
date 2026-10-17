import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/design_system/components/dealgo_primary_button.dart';
import '../../../../core/design_system/tokens/dealgo_tokens.dart';
import '../../domain/entities/ride_money.dart';
import '../../domain/entities/ride_models.dart';
import '../../domain/entities/ride_vehicle.dart';
import '../utils/ride_routes.dart';
import '../widgets/ride_widgets.dart';

class _VehicleChoice {
  const _VehicleChoice({
    required this.kind,
    required this.title,
    required this.subtitle,
    required this.fromFareVnd,
    required this.icon,
    this.assetPath,
  });

  final RideVehicleKind kind;
  final String title;
  final String subtitle;
  final int fromFareVnd;
  final IconData icon;
  final String? assetPath;
}

const _choices = <_VehicleChoice>[
  _VehicleChoice(
    kind: RideVehicleKind.bike,
    title: 'Xe máy',
    subtitle: 'Tiện lợi • 1 khách',
    fromFareVnd: 25000,
    icon: Icons.two_wheeler,
    assetPath: 'assets/images/vehicle_scooter_white.png',
  ),
  _VehicleChoice(
    kind: RideVehicleKind.car4,
    title: 'Xe 4 chỗ',
    subtitle: '1-4 khách • Từ 12 phút',
    fromFareVnd: rideDefaultOfferVnd,
    icon: Icons.directions_car_filled,
  ),
  _VehicleChoice(
    kind: RideVehicleKind.car7,
    title: 'Xe 7 chỗ',
    subtitle: 'Nhóm đông, nhiều hành lý',
    fromFareVnd: 65000,
    icon: Icons.airport_shuttle,
  ),
];

class RideVehiclePage extends StatefulWidget {
  const RideVehiclePage({required this.places, super.key});

  final RidePlaces places;

  @override
  State<RideVehiclePage> createState() => _RideVehiclePageState();
}

class _RideVehiclePageState extends State<RideVehiclePage> {
  var _selected = RideVehicleKind.car4;

  void _continue() {
    context.push(
      RideRoutes.fareBreakdown,
      extra: RideBookingDraft(places: widget.places, vehicleKind: _selected),
    );
  }

  void _back() {
    if (context.canPop()) {
      context.pop();
      return;
    }
    context.go('/customer');
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Scaffold(
      backgroundColor: DealGoColors.canvas,
      body: SafeArea(
        child: Column(
          children: [
            RideScreenHeader(title: 'Chọn loại xe', onBack: _back),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(
                  DealGoDimensions.pageGutter,
                  DealGoSpacing.s8,
                  DealGoDimensions.pageGutter,
                  DealGoSpacing.s16,
                ),
                children: [
                  RidePanel(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const RideSectionTitle('Lộ trình của bạn'),
                        const SizedBox(height: DealGoSpacing.s12),
                        RideStopList(
                          pickup: widget.places.pickup.label,
                          dropoff: widget.places.dropoff.label,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: DealGoSpacing.s12),
                  RidePanel(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Đà Nẵng • Hành trình dự kiến',
                          style: textTheme.bodySmall,
                        ),
                        const SizedBox(height: DealGoSpacing.s12),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(
                            DealGoRadius.input,
                          ),
                          child: const SizedBox(
                            height: 120,
                            width: double.infinity,
                            child: DecoratedBox(
                              decoration: BoxDecoration(
                                color: Color(0xFFF4F0FA),
                              ),
                              child: CustomPaint(painter: _MiniRoutePainter()),
                            ),
                          ),
                        ),
                        const SizedBox(height: DealGoSpacing.s8),
                        Align(
                          alignment: Alignment.centerRight,
                          child: RideStatusChip(
                            label: '12 phút • ~5,2 km',
                            tone: RideChipTone.purple,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: DealGoSpacing.s16),
                  Text('Chọn phương tiện', style: textTheme.titleMedium),
                  const SizedBox(height: DealGoSpacing.s12),
                  for (final choice in _choices) ...[
                    _VehicleTile(
                      choice: choice,
                      selected: choice.kind == _selected,
                      onTap: () => setState(() => _selected = choice.kind),
                    ),
                    const SizedBox(height: DealGoSpacing.s12),
                  ],
                  DecoratedBox(
                    decoration: BoxDecoration(
                      color: DealGoColors.greenSurface,
                      borderRadius: BorderRadius.circular(DealGoRadius.input),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(DealGoSpacing.s12),
                      child: Text(
                        'Giá đang hiển thị là giá minh họa của phiên báo giá này, được xác nhận trước khi đặt xe.',
                        style: textTheme.bodySmall?.copyWith(
                          color: DealGoColors.brandGreen,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(
                DealGoDimensions.pageGutter,
                DealGoSpacing.s8,
                DealGoDimensions.pageGutter,
                DealGoSpacing.s12,
              ),
              child: DealGoPrimaryButton(
                key: const Key('ride-confirm-vehicle'),
                label: 'Xem giá chi tiết',
                trailingIcon: Icons.arrow_forward,
                onPressed: _continue,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _VehicleTile extends StatelessWidget {
  const _VehicleTile({
    required this.choice,
    required this.selected,
    required this.onTap,
  });

  final _VehicleChoice choice;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final fare = choice.kind == RideVehicleKind.car4
        ? formatRideVnd(choice.fromFareVnd)
        : 'Từ ${formatRideVnd(choice.fromFareVnd)}';
    final asset = choice.assetPath;
    return Material(
      color: selected ? DealGoColors.subtlePurple : DealGoColors.card,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(DealGoRadius.card),
        side: BorderSide(
          color: selected ? DealGoColors.primary : DealGoColors.border,
          width: selected ? 1.6 : 1,
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        key: Key('ride-vehicle-${choice.kind.name}'),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(DealGoSpacing.s16),
          child: Row(
            children: [
              SizedBox(
                width: 48,
                height: 48,
                child: asset == null
                    ? Icon(choice.icon, color: DealGoColors.primary)
                    : Image.asset(asset, fit: BoxFit.contain),
              ),
              const SizedBox(width: DealGoSpacing.s12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            choice.title,
                            style: textTheme.titleMedium,
                          ),
                        ),
                        if (selected) ...[
                          const SizedBox(width: DealGoSpacing.s8),
                          RideStatusChip(
                            label: 'Đã chọn',
                            tone: RideChipTone.purple,
                          ),
                        ],
                      ],
                    ),
                    Text(choice.subtitle, style: textTheme.bodySmall),
                  ],
                ),
              ),
              const SizedBox(width: DealGoSpacing.s8),
              Text(
                fare,
                style: textTheme.titleMedium?.copyWith(
                  color: DealGoColors.primary,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MiniRoutePainter extends CustomPainter {
  const _MiniRoutePainter();

  @override
  void paint(Canvas canvas, Size size) {
    final road = Paint()
      ..color = const Color(0xFFE7E3EF)
      ..strokeWidth = 10
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    final route = Paint()
      ..color = DealGoColors.primary
      ..strokeWidth = 4
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(
      Offset(size.width * 0.15, size.height * 0.7),
      Offset(size.width * 0.85, size.height * 0.25),
      road,
    );
    canvas.drawLine(
      Offset(size.width * 0.15, size.height * 0.7),
      Offset(size.width * 0.85, size.height * 0.25),
      route,
    );
    final start = Paint()..color = DealGoColors.brandGreen;
    final end = Paint()..color = DealGoColors.danger;
    canvas.drawCircle(Offset(size.width * 0.15, size.height * 0.7), 6, start);
    canvas.drawCircle(Offset(size.width * 0.85, size.height * 0.25), 6, end);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
