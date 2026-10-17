import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/network/api_error_l10n.dart';
import '../../../../core/network/api_exception.dart';
import '../../../../core/design_system/components/dealgo_secondary_button.dart';
import '../../../../core/design_system/tokens/dealgo_tokens.dart';
import '../../../../l10n/app_localizations.dart';
import '../../domain/entities/ride_money.dart';
import '../../domain/entities/ride_models.dart';
import '../../domain/usecases/cancel_ride.dart';
import '../../domain/usecases/get_ride.dart';
import '../cubit/ride_matching_cubit.dart';
import '../utils/ride_routes.dart';
import '../cubit/ride_session.dart';
import '../widgets/ride_widgets.dart';

class RideMatchingPage extends StatelessWidget {
  const RideMatchingPage({required this.rideId, this.clock, super.key});

  final String rideId;
  final DateTime Function()? clock;

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) => RideMatchingCubit(
        getRide: context.read<GetRide>(),
        cancelRide: context.read<CancelRide>(),
      ),
      child: _RideMatchingView(rideId: rideId, clock: clock),
    );
  }
}

class _RideMatchingView extends StatefulWidget {
  const _RideMatchingView({required this.rideId, this.clock});

  final String rideId;
  final DateTime Function()? clock;

  @override
  State<_RideMatchingView> createState() => _RideMatchingPageState();
}

class _RideMatchingPageState extends State<_RideMatchingView> {
  RideView? _ride;
  var _loading = true;
  var _busy = false;
  var _offline = false;
  var _openedTracking = false;
  String? _message;

  DateTime get _now => (widget.clock ?? DateTime.now)();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    if (_busy) {
      return;
    }
    final token = rideAccessToken(context);
    if (token == null) {
      setState(() {
        _loading = false;
        _offline = false;
        _message = sessionExpiredMessage(context);
      });
      return;
    }
    setState(() {
      _busy = true;
      _message = null;
    });
    try {
      final ride = await context.read<RideMatchingCubit>().load(
        accessToken: token,
        rideId: widget.rideId,
      );
      if (!mounted) {
        return;
      }
      final session = context.read<RideSessionCubit>();
      final waiting =
          ride.status == RideStatus.negotiating &&
          ride.selectedOfferId == null &&
          !rideNegotiationExpired(ride, _now);
      if (waiting) {
        session.remember(ride.id);
      } else {
        session.clear();
      }
      setState(() {
        _ride = ride;
        _loading = false;
        _busy = false;
        _offline = false;
      });
      if (ride.status == RideStatus.assigned && !_openedTracking) {
        _openedTracking = true;
        await context.push(RideRoutes.tracking(ride.id));
      }
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _loading = false;
        _busy = false;
        _offline = true;
        _message = error is ApiException
            ? null
            : AppLocalizations.of(context).errorLoadFailed;
      });
    }
  }

  void _editTrip(RideView ride) {
    context.push(
      RideRoutes.fare,
      extra: RidePlaces(
        pickupLabel: ride.pickup.label,
        dropoffLabel: ride.dropoff.label,
      ),
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
    final ride = _ride;
    return PopScope(
      canPop: !_busy,
      child: Scaffold(
        backgroundColor: DealGoColors.canvas,
        body: SafeArea(child: _body(ride)),
      ),
    );
  }

  Widget _body(RideView? ride) {
    if (_loading && ride == null) {
      return Column(
        children: [
          RideScreenHeader(title: 'Đang nhận báo giá', onBack: _back),
          const Expanded(child: Center(child: CircularProgressIndicator())),
        ],
      );
    }
    if (ride == null) {
      return Column(
        children: [
          RideScreenHeader(
            title: 'Đang tìm tài xế',
            subtitle: 'DealGo · Biến thể trạng thái',
            onBack: _back,
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(DealGoDimensions.pageGutter),
              child: _offline
                  ? const RideOfflineNotice(
                      detail:
                          'Chưa tải được yêu cầu. Chuyến chưa đổi trạng thái.',
                    )
                  : Text(
                      _message ?? AppLocalizations.of(context).errorLoadFailed,
                    ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(DealGoDimensions.pageGutter),
            child: DealGoSecondaryButton(
              label: AppLocalizations.of(context).actionRetry,
              onPressed: _load,
            ),
          ),
        ],
      );
    }
    if (ride.status == RideStatus.cancelled) {
      return _CancelledMatch(onBack: _back);
    }
    if (rideNegotiationExpired(ride, _now)) {
      return _MatchingTimeout(
        ride: ride,
        busy: _busy,
        onBack: _back,
        onEdit: () => _editTrip(ride),
        onRetry: () => _editTrip(ride),
      );
    }
    if (ride.status == RideStatus.assigned) {
      return _AssignedHandoff(
        onBack: _back,
        onOpen: () => context.push(RideRoutes.tracking(ride.id)),
      );
    }
    return _MatchingWait(
      ride: ride,
      busy: _busy,
      offline: _offline,
      onBack: _back,
      onCancel: () => context.push(RideRoutes.cancel(ride.id)),
      onOpenOffers: ride.offers.isEmpty
          ? null
          : () => context.push(RideRoutes.offers(ride.id)),
    );
  }
}

class _MatchingWait extends StatelessWidget {
  const _MatchingWait({
    required this.ride,
    required this.busy,
    required this.offline,
    required this.onBack,
    required this.onCancel,
    required this.onOpenOffers,
  });

  final RideView ride;
  final bool busy;
  final bool offline;
  final VoidCallback onBack;
  final VoidCallback onCancel;
  final VoidCallback? onOpenOffers;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final offers = onOpenOffers;
    return Column(
      children: [
        RideScreenHeader(title: 'Đang nhận báo giá', onBack: onBack),
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
                    const RideSectionTitle('Yêu cầu đang mở'),
                    const SizedBox(height: DealGoSpacing.s12),
                    RideStopList(
                      pickup: ride.pickup.label,
                      dropoff: ride.dropoff.label,
                    ),
                    const SizedBox(height: DealGoSpacing.s12),
                    Row(
                      children: [
                        const RideStatusChip(
                          label: 'Đã gửi đề xuất',
                          tone: RideChipTone.green,
                        ),
                        const Spacer(),
                        Text(
                          formatRideVnd(ride.offeredFareVnd),
                          style: textTheme.titleMedium?.copyWith(
                            color: DealGoColors.primary,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: DealGoSpacing.s24),
              const _VehicleMark(),
              const SizedBox(height: DealGoSpacing.s16),
              Text(
                'Đang chờ tài xế chào giá...',
                textAlign: TextAlign.center,
                style: textTheme.titleMedium,
              ),
              const SizedBox(height: DealGoSpacing.s8),
              Text(
                'Những báo giá phù hợp sẽ xuất hiện để bạn so sánh và tự chọn tài xế.',
                textAlign: TextAlign.center,
                style: textTheme.bodyMedium?.copyWith(
                  color: DealGoColors.textSecondary,
                ),
              ),
              const SizedBox(height: DealGoSpacing.s16),
              RidePanel(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    RideMoneyLine(
                      label: 'Trạng thái',
                      amount: ride.status.wire,
                    ),
                    if (ride.offers.isEmpty) ...[
                      const SizedBox(height: DealGoSpacing.s8),
                      Text(
                        'Chưa có tài xế chào giá',
                        style: textTheme.titleMedium,
                      ),
                      const SizedBox(height: DealGoSpacing.s4),
                      Text(
                        'Trong khu vực này chưa có báo giá hợp lệ cho yêu cầu hiện tại.',
                        style: textTheme.bodyMedium?.copyWith(
                          color: DealGoColors.textSecondary,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: DealGoSpacing.s16),
              const RidePanel(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    RideSectionTitle('Tiến trình'),
                    SizedBox(height: DealGoSpacing.s12),
                    _MatchStep(
                      label: 'Đã gửi yêu cầu thành công',
                      tone: _StepTone.done,
                    ),
                    _MatchStep(
                      label: 'Đang nhận báo giá từ tài xế',
                      tone: _StepTone.current,
                    ),
                    _MatchStep(
                      label: 'Chờ bạn chọn và xác nhận',
                      tone: _StepTone.pending,
                    ),
                  ],
                ),
              ),
              if (offline) ...[
                const SizedBox(height: DealGoSpacing.s12),
                const RideOfflineNotice(
                  detail:
                      'Chưa làm mới được yêu cầu. Trạng thái chuyến chưa đổi.',
                ),
              ],
              if (offers != null) ...[
                const SizedBox(height: DealGoSpacing.s12),
                DealGoSecondaryButton(label: 'Xem báo giá', onPressed: offers),
              ],
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
          child: DealGoSecondaryButton(
            key: const Key('ride-cancel-search'),
            label: 'Hủy tìm kiếm',
            enabled: !busy,
            onPressed: onCancel,
          ),
        ),
      ],
    );
  }
}

class _MatchingTimeout extends StatelessWidget {
  const _MatchingTimeout({
    required this.ride,
    required this.busy,
    required this.onBack,
    required this.onEdit,
    required this.onRetry,
  });

  final RideView ride;
  final bool busy;
  final VoidCallback onBack;
  final VoidCallback onEdit;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        RideScreenHeader(
          title: 'Đang tìm tài xế',
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
                icon: Icons.timelapse,
                iconColor: DealGoColors.warning,
                background: DealGoColors.amberSurface,
                title: 'Chưa tìm được tài xế',
                message: 'Đã hết khoảng thời gian ghép chuyến thử nghiệm. Chưa có tài xế nào nhận yêu cầu.',
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
                    const RideSectionTitle('Giá đề xuất đang dùng'),
                    const SizedBox(height: DealGoSpacing.s8),
                    RideMoneyLine(
                      label: 'Giá đề xuất',
                      amount: formatRideVnd(ride.offeredFareVnd),
                      emphasize: true,
                    ),
                    const RideMoneyLine(
                      label: 'Phương tiện',
                      amount: rideVehicleLabel,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: DealGoSpacing.s12),
              const RideNote(
                message: 'Yêu cầu cũ được đánh dấu TIMEOUT; nhấn thử lại tạo yêu cầu mới có idempotency key.',
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
          child: RideDualActions(
            secondaryLabel: 'Sửa hành trình',
            primaryLabel: 'Tìm lại tài xế',
            enabled: !busy,
            onSecondary: onEdit,
            onPrimary: onRetry,
          ),
        ),
      ],
    );
  }
}

class _AssignedHandoff extends StatelessWidget {
  const _AssignedHandoff({required this.onBack, required this.onOpen});

  final VoidCallback onBack;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        RideScreenHeader(title: 'Đang nhận báo giá', onBack: onBack),
        const Expanded(
          child: Padding(
            padding: EdgeInsets.all(DealGoDimensions.pageGutter),
            child: Text(
              'Tài xế đã nhận chuyến. Mở màn theo dõi để xem giá đã chốt.',
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.all(DealGoDimensions.pageGutter),
          child: DealGoSecondaryButton(
            label: 'Theo dõi chuyến',
            onPressed: onOpen,
          ),
        ),
      ],
    );
  }
}

class _CancelledMatch extends StatelessWidget {
  const _CancelledMatch({required this.onBack});

  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        RideScreenHeader(title: 'Đang nhận báo giá', onBack: onBack),
        const Expanded(
          child: Padding(
            padding: EdgeInsets.all(DealGoDimensions.pageGutter),
            child: Text('Yêu cầu đã hủy. Đề xuất không còn hiệu lực.'),
          ),
        ),
      ],
    );
  }
}

class _VehicleMark extends StatelessWidget {
  const _VehicleMark();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        DecoratedBox(
          decoration: BoxDecoration(
            color: DealGoColors.subtlePurple,
            shape: BoxShape.circle,
          ),
          child: const SizedBox(
            width: 96,
            height: 96,
            child: Icon(
              Icons.two_wheeler,
              color: DealGoColors.primary,
              size: 42,
            ),
          ),
        ),
        const SizedBox(height: DealGoSpacing.s8),
        Text(
          rideVehicleLabel,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: DealGoColors.textSecondary,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }
}

enum _StepTone { done, current, pending }

class _MatchStep extends StatelessWidget {
  const _MatchStep({required this.label, required this.tone});

  final String label;
  final _StepTone tone;

  @override
  Widget build(BuildContext context) {
    final (icon, color) = switch (tone) {
      _StepTone.done => (Icons.check_circle, DealGoColors.brandGreen),
      _StepTone.current => (Icons.circle, DealGoColors.primary),
      _StepTone.pending => (Icons.circle_outlined, DealGoColors.textSecondary),
    };
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: DealGoSpacing.s8),
      child: Row(
        children: [
          Icon(icon, color: color, size: 22),
          const SizedBox(width: DealGoSpacing.s12),
          Expanded(child: Text(label)),
        ],
      ),
    );
  }
}
