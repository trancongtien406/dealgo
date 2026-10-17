import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/design_system/tokens/dealgo_tokens.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../ride/domain/entities/ride_models.dart';
import '../../../ride/domain/entities/ride_money.dart';
import '../utils/driver_routes.dart';
import '../widgets/driver_widgets.dart';

enum DriverRidePhase { navigatePickup, arrived, onTrip, complete }

DriverRidePhase parseDriverRidePhase(Object? raw) {
  return switch (raw) {
    'arrived' => DriverRidePhase.arrived,
    'onTrip' => DriverRidePhase.onTrip,
    'complete' => DriverRidePhase.complete,
    _ => DriverRidePhase.navigatePickup,
  };
}

/// D021–D025 — active ride lifecycle fidelity (local phase machine; mock map).
class DriverActiveRidePage extends StatefulWidget {
  const DriverActiveRidePage({
    required this.rideId,
    this.ride,
    this.initialPhase = DriverRidePhase.navigatePickup,
    super.key,
  });

  final String rideId;
  final OpenRide? ride;
  final DriverRidePhase initialPhase;

  @override
  State<DriverActiveRidePage> createState() => _DriverActiveRidePageState();
}

class _DriverActiveRidePageState extends State<DriverActiveRidePage> {
  late DriverRidePhase _phase = widget.initialPhase;

  OpenRide get _ride =>
      widget.ride ??
      OpenRide(
        id: widget.rideId,
        status: 'ASSIGNED',
        pickup: const RidePoint(
          lat: 16.05,
          lng: 108.2,
          label: '123 Nguyễn Văn Linh, Hải Châu',
        ),
        dropoff: const RidePoint(
          lat: 16.04,
          lng: 108.21,
          label: '302 Trần Phú, Hải Châu',
        ),
        offeredFareVnd: 45000,
        referenceFareVnd: 45000,
        expiresAt: '2030-01-01T00:00:00.000Z',
        offerCount: 1,
      );

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final textTheme = Theme.of(context).textTheme;
    final ride = _ride;
    final title = switch (_phase) {
      DriverRidePhase.navigatePickup => l10n.driverActiveNavTitle,
      DriverRidePhase.arrived => l10n.driverActiveArrivedTitle,
      DriverRidePhase.onTrip => l10n.driverActiveOnTripTitle,
      DriverRidePhase.complete => l10n.driverActiveCompleteTitle,
    };
    final footer = switch (_phase) {
      DriverRidePhase.navigatePickup => DriverFooter(
        secondaryLabel: l10n.driverActiveReportIssue,
        primaryLabel: l10n.driverActiveArrivedCta,
        primaryKey: const Key('driver-active-arrived'),
        onSecondary: () =>
            context.push(DriverRoutes.failed(widget.rideId)),
        onPrimary: () => setState(() => _phase = DriverRidePhase.arrived),
      ),
      DriverRidePhase.arrived => DriverFooter(
        secondaryLabel: l10n.driverActiveReportIssue,
        primaryLabel: l10n.driverActiveOpenOtp,
        primaryKey: const Key('driver-active-open-otp'),
        onSecondary: () =>
            context.push(DriverRoutes.failed(widget.rideId)),
        onPrimary: () => context.push(
          DriverRoutes.passengerOtp(widget.rideId),
          extra: ride,
        ),
      ),
      DriverRidePhase.onTrip => DriverFooter(
        secondaryLabel: l10n.driverActiveReportIssue,
        primaryLabel: l10n.driverActiveCompleteCta,
        primaryKey: const Key('driver-active-complete'),
        onSecondary: () =>
            context.push(DriverRoutes.failed(widget.rideId)),
        onPrimary: () => setState(() => _phase = DriverRidePhase.complete),
      ),
      DriverRidePhase.complete => DriverFooter(
        secondaryLabel: l10n.driverBackToJobs,
        primaryLabel: l10n.driverOpenCompletedSample,
        primaryKey: const Key('driver-active-done'),
        onSecondary: () => context.go('/driver/jobs'),
        onPrimary: () =>
            context.push(DriverRoutes.completed(widget.rideId)),
      ),
    };

    return DriverPageFrame(
      title: title,
      insetBottom: true,
      onBack: () => driverBack(context),
      footer: footer,
      body: ListView(
        padding: const EdgeInsets.fromLTRB(
          DealGoDimensions.pageGutter,
          DealGoSpacing.s8,
          DealGoDimensions.pageGutter,
          DealGoSpacing.s16,
        ),
        children: [
          if (_phase == DriverRidePhase.navigatePickup ||
              _phase == DriverRidePhase.onTrip) ...[
            DriverPanel(
              color: const Color(0xFF1E1B4B),
              child: Row(
                children: [
                  Icon(
                    _phase == DriverRidePhase.onTrip
                        ? Icons.navigation
                        : Icons.turn_right,
                    color: Colors.white,
                  ),
                  const SizedBox(width: DealGoSpacing.s12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _phase == DriverRidePhase.onTrip
                              ? 'Tiếp tục theo lộ trình'
                              : 'Rẽ phải sau 200 m',
                          style: textTheme.titleMedium?.copyWith(
                            color: Colors.white,
                          ),
                        ),
                        Text(
                          _phase == DriverRidePhase.onTrip
                              ? ride.dropoff.label
                              : 'Vào đường Nguyễn Văn Linh',
                          style: textTheme.bodySmall?.copyWith(
                            color: Colors.white70,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: DealGoSpacing.s12),
            ClipRRect(
              borderRadius: BorderRadius.circular(DealGoRadius.card),
              child: const SizedBox(
                height: 160,
                child: ColoredBox(
                  color: Color(0xFFE7EEF5),
                  child: Center(
                    child: Icon(
                      Icons.map_outlined,
                      size: 40,
                      color: DealGoColors.primary,
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: DealGoSpacing.s12),
          ],
          DriverPanel(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _phase == DriverRidePhase.onTrip
                                ? 'Còn 12 phút'
                                : 'Còn 4 phút',
                            style: textTheme.titleMedium,
                          ),
                          Text(
                            _phase == DriverRidePhase.onTrip
                                ? '3,4 km đến điểm đến'
                                : '1,2 km đến điểm đón',
                            style: textTheme.bodySmall,
                          ),
                        ],
                      ),
                    ),
                    DriverChip(
                      label: switch (_phase) {
                        DriverRidePhase.navigatePickup => 'Đang đón',
                        DriverRidePhase.arrived => 'Chờ khách',
                        DriverRidePhase.onTrip => 'Đang chạy',
                        DriverRidePhase.complete => 'Hoàn tất',
                      },
                      tone: DriverChipTone.green,
                    ),
                  ],
                ),
                const SizedBox(height: DealGoSpacing.s12),
                Row(
                  children: [
                    const CircleAvatar(
                      backgroundColor: DealGoColors.subtlePurple,
                      child: Text(
                        'T',
                        style: TextStyle(
                          color: DealGoColors.primary,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    const SizedBox(width: DealGoSpacing.s12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Trần Minh Anh', style: textTheme.titleMedium),
                          Text(
                            ride.pickup.label,
                            style: textTheme.bodySmall,
                          ),
                        ],
                      ),
                    ),
                    IconButton.outlined(
                      onPressed: () {},
                      icon: const Icon(Icons.phone_outlined),
                    ),
                    IconButton.outlined(
                      onPressed: () {},
                      icon: const Icon(Icons.chat_bubble_outline),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: DealGoSpacing.s12),
          DriverPanel(
            color: DealGoColors.subtlePurple,
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Chuyến #${ride.id}', style: textTheme.titleMedium),
                      Text(
                        'Honda Vision · 43H1-123.45',
                        style: textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      formatRideVnd(ride.offeredFareVnd),
                      style: textTheme.titleLarge?.copyWith(
                        color: DealGoColors.primary,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    Text('Giá đã chốt', style: textTheme.bodySmall),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: DealGoSpacing.s12),
          DriverNote(
            tone: DriverNoteTone.green,
            message: switch (_phase) {
              DriverRidePhase.navigatePickup =>
                'Bản đồ thật chưa gắn SDK. Màn D021 là mock điều hướng đón khách.',
              DriverRidePhase.arrived => l10n.driverActiveWaitingBody,
              DriverRidePhase.onTrip => l10n.driverActiveOnTripBody,
              DriverRidePhase.complete => l10n.driverActiveCompleteBody,
            },
          ),
          if (_phase == DriverRidePhase.complete) ...[
            const SizedBox(height: DealGoSpacing.s12),
            DriverPanel(
              child: Column(
                children: [
                  DriverMoneyRow(
                    label: 'Giá đã chốt',
                    value: formatRideVnd(ride.offeredFareVnd),
                    emphasize: true,
                  ),
                  const DriverMoneyRow(
                    label: 'Thu tiền',
                    value: 'Theo hình thức khách đã chọn trên máy chủ',
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}
