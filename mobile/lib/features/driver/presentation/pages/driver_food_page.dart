import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/design_system/tokens/dealgo_tokens.dart';
import '../../../../core/network/api_exception.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../food/domain/entities/food_models.dart';
import '../../../food/domain/entities/food_money.dart';
import '../../domain/usecases/claim_food_order.dart';
import '../cubit/driver_duty_cubit.dart';
import '../cubit/driver_feed_cubit.dart';
import '../cubit/driver_food_cubit.dart';
import '../utils/driver_routes.dart';
import '../widgets/driver_widgets.dart';

enum _FoodPhase { offer, navigate, wait, pickup, deliver, complete }

class DriverFoodDetailPage extends StatelessWidget {
  const DriverFoodDetailPage({required this.job, super.key});

  final ReadyFoodJob job;

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) =>
          DriverFoodCubit(claimFoodOrder: context.read<ClaimFoodOrder>()),
      child: _DriverFoodDetailView(job: job),
    );
  }
}

class _DriverFoodDetailView extends StatefulWidget {
  const _DriverFoodDetailView({required this.job});

  final ReadyFoodJob job;

  @override
  State<_DriverFoodDetailView> createState() => _DriverFoodDetailPageState();
}

class _DriverFoodDetailPageState extends State<_DriverFoodDetailView> {
  var _claiming = false;
  var _taken = false;
  var _phase = _FoodPhase.offer;
  String? _error;
  ClaimedFoodDelivery? _claimed;

  Future<void> _claim() async {
    if (_claiming || _taken || _claimed != null) {
      return;
    }
    final token = driverAccessToken(context);
    if (token == null || token.isEmpty) {
      setState(() => _error = 'Phiên đăng nhập không còn hiệu lực');
      return;
    }
    setState(() {
      _claiming = true;
      _error = null;
    });
    try {
      final claimed = await context.read<DriverFoodCubit>().claim(
        accessToken: token,
        orderId: widget.job.id,
      );
      if (!mounted) {
        return;
      }
      setState(() {
        _claiming = false;
        _claimed = claimed;
        _phase = _FoodPhase.navigate;
      });
    } on ApiException catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _claiming = false;
        if (error.statusCode == 409 &&
            error.errorCode == 'FOOD_ALREADY_ASSIGNED') {
          _taken = true;
          _error = null;
          return;
        }
        _error = error.message;
      });
    } catch (_) {
      if (!mounted) {
        return;
      }
      setState(() {
        _claiming = false;
        _error = 'Không nhận được việc';
      });
    }
  }

  Future<void> _refreshFeed() async {
    await context.read<DriverFeedCubit>().sync(
      online: context.read<DriverDutyCubit>().state,
      accessToken: driverAccessToken(context),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_taken) {
      return _JobTaken(job: widget.job, onRefresh: _refreshFeed);
    }
    if (_phase != _FoodPhase.offer && _claimed != null) {
      return _FoodLifecycle(
        job: widget.job,
        claimed: _claimed!,
        phase: _phase,
        onPhase: (phase) => setState(() => _phase = phase),
        onBack: () => driverBack(context),
      );
    }
    final l10n = AppLocalizations.of(context);
    final textTheme = Theme.of(context).textTheme;
    final job = widget.job;
    return Scaffold(
      body: DriverPageFrame(
        title: 'Chi tiết yêu cầu giao món',
        insetBottom: true,
        onBack: () => driverBack(context),
        footer: DriverFooter(
          secondaryLabel: 'Bỏ qua',
          primaryLabel: 'Nhận việc',
          primaryKey: const Key('driver-claim-job'),
          primaryEnabled: !_claiming,
          primaryLoading: _claiming,
          onSecondary: () => driverBack(context),
          onPrimary: _claim,
        ),
        body: ListView(
          padding: const EdgeInsets.fromLTRB(
            DealGoDimensions.pageGutter,
            DealGoSpacing.s8,
            DealGoDimensions.pageGutter,
            DealGoSpacing.s16,
          ),
          children: [
            DriverPanel(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Thông tin việc', style: textTheme.titleMedium),
                  const SizedBox(height: DealGoSpacing.s8),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          'Đơn #${job.id}',
                          style: textTheme.bodyMedium?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      const DriverChip(
                        label: 'v1 • Dữ liệu đồng bộ',
                        tone: DriverChipTone.neutral,
                      ),
                    ],
                  ),
                  const SizedBox(height: DealGoSpacing.s12),
                  Text('Bún Bò Huế O Cô', style: textTheme.titleMedium),
                  Text(
                    '123 Lê Lợi, Hải Châu, Đà Nẵng',
                    style: textTheme.bodySmall,
                  ),
                  const SizedBox(height: DealGoSpacing.s12),
                  DriverMoneyRow(
                    label: 'Phí giao khách thanh toán',
                    value: formatVnd(job.deliveryFareVnd),
                    emphasize: true,
                  ),
                  DriverMoneyRow(
                    label: 'Thu nhập tài xế dự kiến',
                    value: l10n.driverFoodIncomePending,
                    emphasize: true,
                  ),
                ],
              ),
            ),
            const SizedBox(height: DealGoSpacing.s12),
            DriverPanel(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Điểm nhận và giao', style: textTheme.titleMedium),
                  const SizedBox(height: DealGoSpacing.s12),
                  const DriverStop(
                    color: DealGoColors.brandGreen,
                    label: 'Điểm lấy món',
                    value: '123 Lê Lợi, Hải Châu, Đà Nẵng',
                  ),
                  const SizedBox(height: DealGoSpacing.s12),
                  DriverStop(
                    color: DealGoColors.danger,
                    label: 'Giao cho khách',
                    value: job.dropoff.label,
                  ),
                ],
              ),
            ),
            const SizedBox(height: DealGoSpacing.s12),
            DriverPanel(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Thông tin tài chính', style: textTheme.titleMedium),
                  const SizedBox(height: DealGoSpacing.s8),
                  DriverMoneyRow(
                    label: l10n.driverFoodCodCollect,
                    value: formatVnd(job.totalVnd),
                    emphasize: true,
                  ),
                  DriverMoneyRow(
                    label: 'Tiền món (subtotal)',
                    value: formatVnd(job.subtotalVnd),
                  ),
                  DriverMoneyRow(
                    label: 'Phí giao (server)',
                    value: formatVnd(job.deliveryFareVnd),
                  ),
                ],
              ),
            ),
            const SizedBox(height: DealGoSpacing.s12),
            DriverNote(
              tone: DriverNoteTone.green,
              message:
                  'Khoản COD ${formatVnd(job.totalVnd)} là tiền thu hộ; không phải doanh thu cá nhân. ${l10n.driverFoodNoClientFee}',
            ),
            if (_error != null) ...[
              const SizedBox(height: DealGoSpacing.s12),
              DriverNote(message: _error!),
            ],
          ],
        ),
      ),
    );
  }
}

class _FoodLifecycle extends StatelessWidget {
  const _FoodLifecycle({
    required this.job,
    required this.claimed,
    required this.phase,
    required this.onPhase,
    required this.onBack,
  });

  final ReadyFoodJob job;
  final ClaimedFoodDelivery claimed;
  final _FoodPhase phase;
  final ValueChanged<_FoodPhase> onPhase;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final textTheme = Theme.of(context).textTheme;
    final title = switch (phase) {
      _FoodPhase.navigate => l10n.driverFoodPhaseNavTitle,
      _FoodPhase.wait => l10n.driverFoodPhaseWaitTitle,
      _FoodPhase.pickup => l10n.driverFoodPhasePickupTitle,
      _FoodPhase.deliver => l10n.driverFoodPhaseDeliverTitle,
      _FoodPhase.complete => l10n.driverFoodPhaseCompleteTitle,
      _FoodPhase.offer => 'Chi tiết yêu cầu giao món',
    };
    final footer = switch (phase) {
      _FoodPhase.navigate => DriverFooter(
        secondaryLabel: l10n.driverActiveReportIssue,
        primaryLabel: l10n.driverFoodArrivedStore,
        primaryKey: const Key('driver-arrived-pickup'),
        onSecondary: () => context.push(DriverRoutes.failed(job.id)),
        onPrimary: () => onPhase(_FoodPhase.wait),
      ),
      _FoodPhase.wait => DriverFooter(
        secondaryLabel: l10n.driverActiveReportIssue,
        primaryLabel: l10n.driverFoodConfirmPickup,
        primaryKey: const Key('driver-food-pickup'),
        onSecondary: () => context.push(DriverRoutes.failed(job.id)),
        onPrimary: () => onPhase(_FoodPhase.pickup),
      ),
      _FoodPhase.pickup => DriverFooter(
        secondaryLabel: l10n.actionBack,
        primaryLabel: l10n.driverFoodArrivedCustomer,
        primaryKey: const Key('driver-food-deliver'),
        onSecondary: () => onPhase(_FoodPhase.wait),
        onPrimary: () => onPhase(_FoodPhase.deliver),
      ),
      _FoodPhase.deliver => DriverFooter(
        secondaryLabel: l10n.driverActiveReportIssue,
        primaryLabel: l10n.driverFoodCompleteDelivery,
        primaryKey: const Key('driver-food-complete'),
        onSecondary: () => context.push(DriverRoutes.failed(job.id)),
        onPrimary: () => onPhase(_FoodPhase.complete),
      ),
      _FoodPhase.complete => DriverFooter(
        secondaryLabel: l10n.driverBackToJobs,
        primaryLabel: l10n.tabHome,
        primaryKey: const Key('driver-food-home'),
        onSecondary: () => context.go('/driver/jobs'),
        onPrimary: () => context.go('/driver'),
      ),
      _FoodPhase.offer => null,
    };

    return Scaffold(
      body: DriverPageFrame(
        title: title,
        insetBottom: true,
        onBack: onBack,
        footer: footer,
        body: ListView(
          padding: const EdgeInsets.fromLTRB(
            DealGoDimensions.pageGutter,
            DealGoSpacing.s8,
            DealGoDimensions.pageGutter,
            DealGoSpacing.s16,
          ),
          children: [
            if (phase == _FoodPhase.complete) ...[
              const Center(
                child: Icon(
                  Icons.check_circle,
                  size: 56,
                  color: DealGoColors.brandGreen,
                ),
              ),
              const SizedBox(height: DealGoSpacing.s12),
              Text(
                'Đã giao thành công',
                textAlign: TextAlign.center,
                style: textTheme.titleLarge,
              ),
              Text(
                'Đơn #${job.id} · trạng thái ${claimed.status}',
                textAlign: TextAlign.center,
                style: textTheme.bodySmall,
              ),
              const SizedBox(height: DealGoSpacing.s16),
            ],
            if (phase == _FoodPhase.navigate || phase == _FoodPhase.deliver) ...[
              DriverPanel(
                color: const Color(0xFF1E1B4B),
                child: Row(
                  children: [
                    const Icon(Icons.turn_right, color: Colors.white),
                    const SizedBox(width: DealGoSpacing.s12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            phase == _FoodPhase.deliver
                                ? 'Đến điểm giao'
                                : 'Rẽ phải sau 200 m',
                            style: textTheme.titleMedium?.copyWith(
                              color: Colors.white,
                            ),
                          ),
                          Text(
                            phase == _FoodPhase.deliver
                                ? job.dropoff.label
                                : 'Vào đường Lê Lợi',
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
            ],
            DriverPanel(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text('Đơn #${job.id}', style: textTheme.titleMedium),
                      ),
                      DriverChip(
                        label: switch (phase) {
                          _FoodPhase.navigate => 'Đang đón',
                          _FoodPhase.wait => 'Chờ món',
                          _FoodPhase.pickup => 'Đã lấy',
                          _FoodPhase.deliver => 'Đang giao',
                          _FoodPhase.complete => 'DELIVERED',
                          _FoodPhase.offer => 'OPEN',
                        },
                        tone: DriverChipTone.green,
                      ),
                    ],
                  ),
                  const SizedBox(height: DealGoSpacing.s8),
                  Text(
                    'Trạng thái máy chủ · ${claimed.status}',
                    style: textTheme.bodySmall,
                  ),
                  const SizedBox(height: DealGoSpacing.s12),
                  DriverMoneyRow(
                    label: 'Phí giao',
                    value: formatVnd(job.deliveryFareVnd),
                    emphasize: true,
                  ),
                  DriverMoneyRow(
                    label: l10n.driverFoodCodCollect,
                    value: formatVnd(job.totalVnd),
                    emphasize: true,
                  ),
                ],
              ),
            ),
            const SizedBox(height: DealGoSpacing.s12),
            DriverNote(
              tone: DriverNoteTone.green,
              message: switch (phase) {
                _FoodPhase.navigate =>
                  'Bản đồ thật chưa gắn SDK. Màn D026 là mock điều hướng tới quán.',
                _FoodPhase.wait => l10n.driverFoodWaitBody,
                _FoodPhase.pickup => l10n.driverFoodPickupBody,
                _FoodPhase.deliver => l10n.driverFoodDeliverBody,
                _FoodPhase.complete => l10n.driverFoodCompleteBody,
                _FoodPhase.offer => '',
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _JobTaken extends StatelessWidget {
  const _JobTaken({required this.job, required this.onRefresh});

  final ReadyFoodJob job;
  final Future<void> Function() onRefresh;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Scaffold(
      body: DriverPageFrame(
        title: 'Yêu cầu gần tài xế',
        subtitle: driverStateSubtitle,
        insetBottom: true,
        onBack: () => driverBack(context),
        footer: DriverFooter(
          secondaryLabel: 'Làm mới',
          primaryLabel: 'Tìm việc khác',
          onSecondary: () async {
            await onRefresh();
            if (context.mounted) {
              driverBack(context);
            }
          },
          onPrimary: () => driverBack(context),
        ),
        body: ListView(
          padding: const EdgeInsets.fromLTRB(
            DealGoDimensions.pageGutter,
            DealGoSpacing.s12,
            DealGoDimensions.pageGutter,
            DealGoSpacing.s16,
          ),
          children: [
            const DriverHero(
              icon: Icons.swap_horiz,
              iconColor: DealGoColors.amber,
              background: DealGoColors.amberSurface,
              title: 'Yêu cầu đã được nhận',
              message:
                  'Yêu cầu vừa chọn đã được phân công cho tài xế khác hoặc hết thời hạn giữ chỗ.',
            ),
            const SizedBox(height: DealGoSpacing.s24),
            DriverPanel(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Yêu cầu không còn khả dụng',
                    style: textTheme.titleMedium,
                  ),
                  const SizedBox(height: DealGoSpacing.s12),
                  DriverMoneyRow(label: 'Mã yêu cầu', value: job.id),
                  const DriverMoneyRow(label: 'Dịch vụ', value: 'Giao đồ ăn'),
                  const SizedBox(height: DealGoSpacing.s8),
                  const Row(
                    children: [
                      Expanded(child: Text('Trạng thái')),
                      DriverChip(
                        label: 'TAKEN / EXPIRED',
                        tone: DriverChipTone.warning,
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: DealGoSpacing.s12),
            const DriverNote(
              message:
                  'Không giữ nút “Nhận việc” khả dụng sau lỗi 409; làm mới nguồn yêu cầu.',
            ),
          ],
        ),
      ),
    );
  }
}
