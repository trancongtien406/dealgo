import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/design_system/components/dealgo_primary_button.dart';
import '../../../../core/design_system/components/dealgo_secondary_button.dart';
import '../../../../core/design_system/tokens/dealgo_tokens.dart';
import '../../domain/entities/ride_money.dart';
import '../../domain/entities/ride_models.dart';
import '../../domain/entities/ride_vehicle.dart';
import '../../domain/usecases/get_ride.dart';
import '../cubit/ride_receipt_cubit.dart';
import '../widgets/ride_widgets.dart';

class RideReceiptPage extends StatelessWidget {
  const RideReceiptPage({required this.rideId, super.key});

  final String rideId;

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) => RideReceiptCubit(getRide: context.read<GetRide>()),
      child: _RideReceiptView(rideId: rideId),
    );
  }
}

class _RideReceiptView extends StatefulWidget {
  const _RideReceiptView({required this.rideId});

  final String rideId;

  @override
  State<_RideReceiptView> createState() => _RideReceiptPageState();
}

class _RideReceiptPageState extends State<_RideReceiptView> {
  RideView? _ride;
  var _loading = true;
  var _offline = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    final token = rideAccessToken(context);
    if (token == null) {
      setState(() {
        _loading = false;
        _offline = true;
      });
      return;
    }
    try {
      final ride = await context.read<RideReceiptCubit>().load(
        accessToken: token,
        rideId: widget.rideId,
      );
      if (!mounted) {
        return;
      }
      setState(() {
        _ride = ride;
        _loading = false;
        _offline = false;
      });
    } catch (_) {
      if (!mounted) {
        return;
      }
      setState(() {
        _loading = false;
        _offline = true;
      });
    }
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
    final ride = _ride;
    final textTheme = Theme.of(context).textTheme;
    return Scaffold(
      backgroundColor: DealGoColors.canvas,
      body: SafeArea(
        child: Column(
          children: [
            RideScreenHeader(
              title: 'Biên nhận chuyến đi',
              onBack: _back,
              trailing: Text(
                'DealGo',
                style: textTheme.titleMedium?.copyWith(
                  color: DealGoColors.primary,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            Expanded(child: _body(ride, textTheme)),
            if (ride != null && ride.agreedFareVnd != null)
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  DealGoDimensions.pageGutter,
                  DealGoSpacing.s8,
                  DealGoDimensions.pageGutter,
                  DealGoSpacing.s12,
                ),
                child: Column(
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: DealGoSecondaryButton(
                            label: 'Hỗ trợ',
                            onPressed: () {},
                          ),
                        ),
                        const SizedBox(width: DealGoSpacing.s12),
                        Expanded(
                          child: DealGoSecondaryButton(
                            label: 'Lưu biên nhận',
                            onPressed: () {},
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: DealGoSpacing.s8),
                    DealGoPrimaryButton(
                      label: 'Đánh giá chuyến đi',
                      trailingIcon: Icons.arrow_forward,
                      onPressed: () {},
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _body(RideView? ride, TextTheme textTheme) {
    if (_loading && ride == null) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_offline && ride == null) {
      return const Padding(
        padding: EdgeInsets.all(DealGoDimensions.pageGutter),
        child: RideOfflineNotice(
          detail: 'Chưa tải được biên nhận. Giá đã chốt chưa được hiển thị.',
        ),
      );
    }
    if (ride == null) {
      return const SizedBox.shrink();
    }
    final agreed = ride.agreedFareVnd;
    final voucher = agreed == null ? 0 : 4000;
    final listed = agreed == null ? null : agreed + voucher;
    return ListView(
      padding: const EdgeInsets.fromLTRB(
        DealGoDimensions.pageGutter,
        DealGoSpacing.s8,
        DealGoDimensions.pageGutter,
        DealGoSpacing.s24,
      ),
      children: [
        const Center(
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: DealGoColors.greenSurface,
              shape: BoxShape.circle,
            ),
            child: SizedBox(
              width: 72,
              height: 72,
              child: Icon(
                Icons.check,
                color: DealGoColors.brandGreen,
                size: 36,
              ),
            ),
          ),
        ),
        const SizedBox(height: DealGoSpacing.s16),
        Text(
          'Chuyến đi hoàn tất!',
          textAlign: TextAlign.center,
          style: textTheme.titleLarge,
        ),
        const SizedBox(height: DealGoSpacing.s4),
        Text(
          'Cảm ơn bạn đã đồng hành cùng DealGo',
          textAlign: TextAlign.center,
          style: textTheme.bodySmall,
        ),
        const SizedBox(height: DealGoSpacing.s12),
        if (agreed == null)
          const RideNote(message: 'Máy chủ chưa trả giá đã chốt.')
        else
          Text(
            formatRideVnd(agreed),
            key: const Key('ride-receipt-fare'),
            textAlign: TextAlign.center,
            style: textTheme.headlineSmall?.copyWith(
              color: DealGoColors.primary,
              fontWeight: FontWeight.w800,
            ),
          ),
        if (agreed != null) ...[
          const SizedBox(height: DealGoSpacing.s4),
          Text(
            'Đã thanh toán bằng tiền mặt',
            textAlign: TextAlign.center,
            style: textTheme.bodySmall,
          ),
        ],
        const SizedBox(height: DealGoSpacing.s16),
        RidePanel(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'Biên nhận #${rideQuoteDisplayId(ride.id)}',
                      style: textTheme.titleMedium,
                    ),
                  ),
                  const RideStatusChip(
                    label: 'Hoàn tất',
                    tone: RideChipTone.green,
                  ),
                ],
              ),
              const SizedBox(height: DealGoSpacing.s12),
              RideStopList(
                pickup: ride.pickup.label,
                dropoff: ride.dropoff.label,
              ),
              const SizedBox(height: DealGoSpacing.s12),
              const RideMoneyLine(label: 'Ngày', amount: '14/10/2026'),
              const RideMoneyLine(label: 'Thời gian', amount: '14:32 – 14:45'),
              const RideMoneyLine(
                label: 'Phương tiện',
                amount: 'Xe 4 chỗ • Toyota Vios',
              ),
            ],
          ),
        ),
        const SizedBox(height: DealGoSpacing.s12),
        RidePanel(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const RideSectionTitle('Chi tiết thanh toán'),
              const SizedBox(height: DealGoSpacing.s8),
              if (agreed != null && listed != null) ...[
                RideMoneyLine(
                  label: 'Giá chuyến được chốt',
                  amount: formatRideVnd(listed),
                ),
                RideMoneyLine(
                  label: 'Voucher DealGo',
                  amount: '-${formatRideVnd(voucher)}',
                ),
                RideMoneyLine(
                  label: 'Tổng thanh toán',
                  amount: formatRideVnd(agreed),
                  emphasize: true,
                ),
              ] else
                const RideNote(message: 'Chưa có số tiền đã chốt từ máy chủ.'),
            ],
          ),
        ),
      ],
    );
  }
}
