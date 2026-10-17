import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/design_system/components/dealgo_primary_button.dart';
import '../../../../core/design_system/components/dealgo_secondary_button.dart';
import '../../../../core/design_system/tokens/dealgo_tokens.dart';
import '../../domain/entities/ride_money.dart';
import '../../domain/entities/ride_models.dart';
import '../widgets/ride_widgets.dart';

class RideConfirmPage extends StatefulWidget {
  const RideConfirmPage({required this.args, super.key});

  final RideConfirmArgs args;

  @override
  State<RideConfirmPage> createState() => _RideConfirmPageState();
}

class _RideConfirmPageState extends State<RideConfirmPage> {
  var _acknowledged = false;

  RideView get _ride => widget.args.ride;

  bool get _fareChanged {
    final agreed = _ride.agreedFareVnd;
    if (agreed == null) {
      return false;
    }
    return agreed != widget.args.tappedAmountVnd;
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
    final agreed = _ride.agreedFareVnd;
    if (agreed == null) {
      return Scaffold(
        backgroundColor: DealGoColors.canvas,
        body: SafeArea(
          child: Column(
            children: [
              RideScreenHeader(title: 'Xác nhận chuyến xe', onBack: _back),
              const Expanded(
                child: Padding(
                  padding: EdgeInsets.all(DealGoDimensions.pageGutter),
                  child: Text(
                    'Máy chủ chưa trả giá đã chốt. Không hiển thị giá khách tự tính.',
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }
    if (_fareChanged && !_acknowledged) {
      return _FareChanged(
        ride: _ride,
        tappedAmountVnd: widget.args.tappedAmountVnd,
        agreedFareVnd: agreed,
        onBack: _back,
        onAccept: () => setState(() => _acknowledged = true),
      );
    }
    return _Confirmed(ride: _ride, agreedFareVnd: agreed, onBack: _back);
  }
}

class _FareChanged extends StatelessWidget {
  const _FareChanged({
    required this.ride,
    required this.tappedAmountVnd,
    required this.agreedFareVnd,
    required this.onBack,
    required this.onAccept,
  });

  final RideView ride;
  final int tappedAmountVnd;
  final int agreedFareVnd;
  final VoidCallback onBack;
  final VoidCallback onAccept;

  @override
  Widget build(BuildContext context) {
    final delta = agreedFareVnd - tappedAmountVnd;
    return Scaffold(
      backgroundColor: DealGoColors.canvas,
      body: SafeArea(
        child: Column(
          children: [
            RideScreenHeader(
              title: 'Xác nhận giá mới',
              subtitle: 'DealGo · Biến thể trạng thái',
              onBack: onBack,
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(
                  DealGoDimensions.pageGutter,
                  DealGoSpacing.s8,
                  DealGoDimensions.pageGutter,
                  DealGoSpacing.s16,
                ),
                children: [
                  const RideStateHero(
                    icon: Icons.priority_high,
                    iconColor: DealGoColors.warning,
                    background: DealGoColors.amberSurface,
                    title: 'Giá chuyến vừa thay đổi',
                    message: 'Điều kiện chuyến thay đổi nên phiên báo giá cũ không còn hợp lệ. Bạn cần thấy rõ giá máy chủ đã chốt.',
                  ),
                  const SizedBox(height: DealGoSpacing.s16),
                  RidePanel(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const RideSectionTitle('Hành trình đang chọn'),
                        const SizedBox(height: DealGoSpacing.s12),
                        RideStopList(
                          pickup: ride.pickup.label,
                          dropoff: ride.dropoff.label,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: DealGoSpacing.s12),
                  RidePanel(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const RideSectionTitle('So sánh hai phiên giá'),
                        const SizedBox(height: DealGoSpacing.s8),
                        RideMoneyLine(
                          label: 'Giá trên dòng bạn chọn',
                          amount: formatRideVnd(tappedAmountVnd),
                        ),
                        RideMoneyLine(
                          label: 'Giá máy chủ đã chốt',
                          amount: formatRideVnd(agreedFareVnd),
                        ),
                        RideMoneyLine(
                          label: 'Chênh lệch',
                          amount: formatRideVndDelta(delta),
                          emphasize: true,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: DealGoSpacing.s12),
                  const RideNote(
                    message: 'Không tự đổi số tiền khách thanh toán. Giá hiệu lực là số máy chủ đã chốt.',
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
              child: Row(
                children: [
                  Expanded(
                    child: DealGoSecondaryButton(
                      label: 'Quay lại',
                      onPressed: onBack,
                    ),
                  ),
                  const SizedBox(width: DealGoSpacing.s12),
                  Expanded(
                    child: DealGoPrimaryButton(
                      key: const Key('ride-ack-fare'),
                      label: 'Đồng ý ${formatRideVnd(agreedFareVnd)}',
                      onPressed: onAccept,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Confirmed extends StatelessWidget {
  const _Confirmed({
    required this.ride,
    required this.agreedFareVnd,
    required this.onBack,
  });

  final RideView ride;
  final int agreedFareVnd;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    final driver = ride.assignedDriverId ?? 'Tài xế';
    final initial = driver.isEmpty ? '?' : driver.substring(0, 1).toUpperCase();
    return Scaffold(
      backgroundColor: DealGoColors.canvas,
      body: SafeArea(
        child: Column(
          children: [
            RideScreenHeader(title: 'Xác nhận chuyến xe', onBack: onBack),
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
                        const RideSectionTitle('Hành trình đã chọn'),
                        const SizedBox(height: DealGoSpacing.s12),
                        RideStopList(
                          pickup: ride.pickup.label,
                          dropoff: ride.dropoff.label,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: DealGoSpacing.s12),
                  RidePanel(
                    child: Row(
                      children: [
                        CircleAvatar(
                          backgroundColor: DealGoColors.subtlePurple,
                          child: Text(
                            initial,
                            style: const TextStyle(
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
                              Text(
                                driver,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: Theme.of(context).textTheme.titleMedium,
                              ),
                              const Text(rideVehicleLabel),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: DealGoSpacing.s12),
                  RidePanel(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const RideSectionTitle('Báo giá được chốt'),
                        const SizedBox(height: DealGoSpacing.s8),
                        const RideStatusChip(
                          label: 'Còn hiệu lực',
                          tone: RideChipTone.green,
                        ),
                        const SizedBox(height: DealGoSpacing.s8),
                        RideMoneyLine(
                          label: 'Cước chuyến',
                          amount: formatRideVnd(agreedFareVnd),
                        ),
                        RideMoneyLine(
                          key: const Key('ride-agreed-fare'),
                          label: 'Khách thanh toán',
                          amount: formatRideVnd(agreedFareVnd),
                          emphasize: true,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: DealGoSpacing.s12),
                  const RidePanel(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        RideSectionTitle('Phương thức thanh toán'),
                        SizedBox(height: DealGoSpacing.s8),
                        Row(
                          children: [
                            Icon(
                              Icons.payments_outlined,
                              color: DealGoColors.brandGreen,
                            ),
                            SizedBox(width: DealGoSpacing.s8),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Tiền mặt',
                                    style: TextStyle(
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                  Text('Chỉ thu tiền khi chuyến đi hoàn tất'),
                                ],
                              ),
                            ),
                            RideStatusChip(
                              label: 'Đã chọn',
                              tone: RideChipTone.green,
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: DealGoSpacing.s12),
                  const RideNote(
                    message: 'Nếu giá thay đổi, DealGo yêu cầu bạn xem và xác nhận lại trước khi áp dụng.',
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
                label: 'Đã ghi nhận ${formatRideVnd(agreedFareVnd)}',
                onPressed: onBack,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
