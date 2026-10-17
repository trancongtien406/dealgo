import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/design_system/components/dealgo_primary_button.dart';
import '../../../../core/design_system/tokens/dealgo_tokens.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../food/domain/entities/food_money.dart';
import '../../../food/domain/entities/food_models.dart';
import '../../../ride/domain/entities/ride_models.dart';
import '../../../ride/domain/entities/ride_money.dart';
import '../cubit/driver_duty_cubit.dart';
import '../cubit/driver_feed_cubit.dart';
import 'driver_home_page.dart';
import '../utils/driver_routes.dart';
import '../widgets/driver_widgets.dart';

class DriverJobsPage extends StatefulWidget {
  const DriverJobsPage({super.key});

  @override
  State<DriverJobsPage> createState() => _DriverJobsPageState();
}

class _DriverJobsPageState extends State<DriverJobsPage> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _sync());
  }

  void _sync() {
    if (!mounted) {
      return;
    }
    unawaited(
      context.read<DriverFeedCubit>().sync(
        online: context.read<DriverDutyCubit>().state,
        accessToken: driverAccessToken(context),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return BlocListener<DriverDutyCubit, bool>(
      listener: (context, online) => _sync(),
      child: BlocBuilder<DriverFeedCubit, DriverFeedState>(
        builder: (context, feed) {
          if (feed is DriverFeedIneligible) {
            return const DriverIneligibleView();
          }
          final online = context.watch<DriverDutyCubit>().state;
          if (!online) {
            return const _JobsOffline();
          }
          return _JobsOnline(feed: feed, onRetry: _sync);
        },
      ),
    );
  }
}

class _JobsOffline extends StatelessWidget {
  const _JobsOffline();

  @override
  Widget build(BuildContext context) {
    return DriverPageFrame(
      title: 'Yêu cầu đang mở',
      subtitle: driverStateSubtitle,
      onBack: () => driverBack(context),
      body: ListView(
        padding: const EdgeInsets.all(DealGoDimensions.pageGutter),
        children: const [
          DriverHero(
            icon: Icons.bolt,
            iconColor: DealGoColors.amber,
            background: DealGoColors.amberSurface,
            title: 'Bạn đang ngoại tuyến',
            message: 'Danh sách việc không được tải khi thiết bị đang offline.',
          ),
          SizedBox(height: DealGoSpacing.s16),
          DriverNote(
            message: 'Offline trên thiết bị không đồng nghĩa backend đã đổi trạng thái ca làm. Cần đồng bộ lại.',
          ),
        ],
      ),
    );
  }
}

class _JobsOnline extends StatelessWidget {
  const _JobsOnline({required this.feed, required this.onRetry});

  final DriverFeedState feed;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final state = feed;
    final DriverFeedReady? ready = state is DriverFeedReady ? state : null;
    final DriverFeedFailed? failed = state is DriverFeedFailed ? state : null;
    final loading = state is DriverFeedLoading || state is DriverFeedIdle;

    return DriverPageFrame(
      title: 'Yêu cầu đang mở',
      onBack: () => driverBack(context),
      footer: ready == null || (ready.rides.isEmpty && ready.food.isEmpty)
          ? null
          : Padding(
              padding: const EdgeInsets.fromLTRB(
                DealGoDimensions.pageGutter,
                DealGoSpacing.s8,
                DealGoDimensions.pageGutter,
                DealGoSpacing.s16,
              ),
              child: DealGoPrimaryButton(
                key: const Key('driver-open-first-job'),
                label: 'Xem chi tiết công việc',
                trailingIcon: Icons.arrow_forward,
                onPressed: () => _openFirst(context, ready),
              ),
            ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(
          DealGoDimensions.pageGutter,
          DealGoSpacing.s8,
          DealGoDimensions.pageGutter,
          DealGoSpacing.s16,
        ),
        children: [
          const DriverPanel(
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Khu vực nhận việc'),
                      SizedBox(height: DealGoSpacing.s4),
                      Text(
                        'Đà Nẵng · Hải Châu',
                        style: TextStyle(fontWeight: FontWeight.w700),
                      ),
                    ],
                  ),
                ),
                DriverChip(label: 'Online', tone: DriverChipTone.green),
              ],
            ),
          ),
          const SizedBox(height: DealGoSpacing.s12),
          DriverPanel(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Chế độ nhận việc', style: textTheme.titleMedium),
                const SizedBox(height: DealGoSpacing.s8),
                const Row(
                  children: [
                    DriverChip(
                      label: 'Giao đồ ăn',
                      tone: DriverChipTone.green,
                    ),
                    SizedBox(width: DealGoSpacing.s8),
                    Expanded(
                      child: Text(
                        'Đã bật · Hồ sơ hợp lệ',
                        style: TextStyle(fontWeight: FontWeight.w600),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: DealGoSpacing.s12),
          if (loading)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: DealGoSpacing.s32),
              child: Text(
                'Đang tải yêu cầu',
                textAlign: TextAlign.center,
                style: textTheme.bodyMedium,
              ),
            ),
          if (failed != null) ...[
            Text(failed.message, style: textTheme.bodyMedium),
            const SizedBox(height: DealGoSpacing.s12),
            DealGoPrimaryButton(
              label: AppLocalizations.of(context).actionRetry,
              onPressed: onRetry,
            ),
          ],
          if (ready != null && ready.rides.isEmpty && ready.food.isEmpty)
            Text(
              'Chưa có yêu cầu đang mở',
              style: textTheme.bodyMedium?.copyWith(
                color: DealGoColors.textSecondary,
              ),
            ),
          if (ready != null && ready.rides.isNotEmpty) ...[
            Text('Chở khách có thể nhận', style: textTheme.titleMedium),
            const SizedBox(height: DealGoSpacing.s8),
            for (final ride in ready.rides) ...[
              _RideJobCard(ride: ride),
              const SizedBox(height: DealGoSpacing.s12),
            ],
          ],
          if (ready != null && ready.food.isNotEmpty) ...[
            Text('Giao đồ ăn có thể nhận', style: textTheme.titleMedium),
            const SizedBox(height: DealGoSpacing.s8),
            for (final job in ready.food) ...[
              _FoodJobCard(job: job),
              const SizedBox(height: DealGoSpacing.s12),
            ],
          ],
          const DriverNote(
            tone: DriverNoteTone.green,
            message: 'Một tài xế chỉ nhận tối đa một công việc đang thực hiện.',
          ),
          const SizedBox(height: DealGoSpacing.s16),
          Text(
            AppLocalizations.of(context).driverJobsHistorySection,
            style: textTheme.titleMedium,
          ),
          const SizedBox(height: DealGoSpacing.s8),
          TextButton(
            key: const Key('driver-open-failed-sample'),
            onPressed: () => context.push(DriverRoutes.failed('job-demo-1')),
            child: Text(AppLocalizations.of(context).driverJobFailedTitle),
          ),
          TextButton(
            key: const Key('driver-open-completed-from-jobs'),
            onPressed: () =>
                context.push(DriverRoutes.completed('job-demo-1')),
            child: Text(AppLocalizations.of(context).driverJobCompletedTitle),
          ),
        ],
      ),
    );
  }

  void _openFirst(BuildContext context, DriverFeedReady ready) {
    if (ready.rides.isNotEmpty) {
      final ride = ready.rides.first;
      context.push(DriverRoutes.ride(ride.id), extra: ride);
      return;
    }
    if (ready.food.isNotEmpty) {
      final job = ready.food.first;
      context.push(DriverRoutes.food(job.id), extra: job);
    }
  }
}

class _RideJobCard extends StatelessWidget {
  const _RideJobCard({required this.ride});

  final OpenRide ride;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return DriverPanel(
      child: InkWell(
        key: Key('driver-ride-${ride.id}'),
        onTap: () => context.push(DriverRoutes.ride(ride.id), extra: ride),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const DriverChip(
                  label: 'Chở khách · Xe máy',
                  tone: DriverChipTone.green,
                ),
                const Spacer(),
                Text('Đã đồng bộ', style: textTheme.bodySmall),
              ],
            ),
            const SizedBox(height: DealGoSpacing.s12),
            Text('Đơn #${ride.id}', style: textTheme.bodySmall),
            const SizedBox(height: DealGoSpacing.s8),
            Text(ride.pickup.label, style: textTheme.titleMedium),
            Text(ride.dropoff.label, style: textTheme.bodySmall),
            const SizedBox(height: DealGoSpacing.s12),
            DriverMoneyRow(
              label: 'Giá khách đề xuất',
              value: formatRideVnd(ride.offeredFareVnd),
              emphasize: true,
            ),
            DriverMoneyRow(
              label: 'Giá tham chiếu',
              value: formatRideVnd(ride.referenceFareVnd),
            ),
          ],
        ),
      ),
    );
  }
}

class _FoodJobCard extends StatelessWidget {
  const _FoodJobCard({required this.job});

  final ReadyFoodJob job;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return DriverPanel(
      child: InkWell(
        key: Key('driver-food-${job.id}'),
        onTap: () => context.push(DriverRoutes.food(job.id), extra: job),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text('Đơn #${job.id}', style: textTheme.bodySmall),
                const Spacer(),
                const DriverChip(
                  label: 'v1 · Dữ liệu đồng bộ',
                  tone: DriverChipTone.neutral,
                ),
              ],
            ),
            const SizedBox(height: DealGoSpacing.s12),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const DecoratedBox(
                  decoration: BoxDecoration(
                    color: DealGoColors.subtlePurple,
                    borderRadius: BorderRadius.all(Radius.circular(12)),
                  ),
                  child: SizedBox(
                    width: 48,
                    height: 48,
                    child: Icon(
                      Icons.storefront_outlined,
                      color: DealGoColors.primary,
                    ),
                  ),
                ),
                const SizedBox(width: DealGoSpacing.s12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Cửa hàng ${job.storeId}',
                        style: textTheme.titleMedium,
                      ),
                      Text(
                        '${job.lineCount} món · ${job.dropoff.label}',
                        style: textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: DealGoSpacing.s12),
            DriverMoneyRow(
              label: 'Giá giao được chấp nhận',
              value: formatVnd(job.deliveryFareVnd),
              emphasize: true,
            ),
            Text(
              'Thu nhập tài xế theo đối soát hệ thống sau khi giao xong.',
              style: textTheme.bodySmall,
            ),
            Text(
              'Chỉ được nhận sau khi Shop xác nhận và tài xế đủ điều kiện.',
              style: textTheme.bodySmall,
            ),
          ],
        ),
      ),
    );
  }
}
