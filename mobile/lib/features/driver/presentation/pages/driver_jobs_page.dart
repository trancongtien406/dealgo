import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/design_system/components/dealgo_primary_button.dart';
import '../../../../core/design_system/components/dealgo_skeleton.dart';
import '../../../../core/design_system/components/dealgo_state_view.dart';
import '../../../../core/design_system/tokens/dealgo_tokens.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../food/domain/entities/food_money.dart';
import '../../../food/domain/entities/food_models.dart';
import '../../../ride/domain/entities/ride_models.dart';
import '../../../ride/domain/entities/ride_money.dart';
import '../cubit/driver_duty_cubit.dart';
import '../cubit/driver_feed_cubit.dart';
import '../cubit/driver_services_cubit.dart';
import 'driver_home_page.dart';
import '../utils/driver_routes.dart';
import '../widgets/driver_widgets.dart';
import '../../../../core/design_system/icons/dealgo_icons.dart';
import '../../../../core/format/short_ref.dart';
import '../../../../core/l10n/api_error_text.dart';
import '../../../../core/network/request_failure.dart';

class DriverJobsPage extends StatefulWidget {
  const DriverJobsPage({super.key});

  @override
  State<DriverJobsPage> createState() => _DriverJobsPageState();
}

class _DriverJobsPageState extends State<DriverJobsPage> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _sync();
      if (mounted) {
        context.read<DriverServicesCubit>().load();
      }
    });
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
    return MultiBlocListener(
      listeners: [
        BlocListener<DriverDutyCubit, bool>(
          listener: (context, online) => _sync(),
        ),
        // A saved service switch changes which jobs the server offers.
        BlocListener<DriverServicesCubit, DriverServicesState>(
          listenWhen: (before, after) => before.saved != after.saved,
          listener: (context, _) => _sync(),
        ),
      ],
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
    final l10n = AppLocalizations.of(context);
    return DriverPageFrame(
      title: l10n.driverOpenRequests,
      onBack: () => driverBack(context),
      body: ListView(
        padding: const EdgeInsets.all(DealGoDimensions.pageGutter),
        children: [
          DriverHero(
            icon: DealGoIcons.bolt,
            iconColor: DealGoColors.amber,
            background: DealGoColors.amberSurface,
            title: l10n.driverOfflineTitle,
            message: l10n.driverJobsOfflineBody,
          ),
          const SizedBox(height: DealGoSpacing.s16),
          DriverNote(message: l10n.driverOfflineNote),
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
    final l10n = AppLocalizations.of(context);
    final services = context.watch<DriverServicesCubit>().state.saved;
    final state = feed;
    final DriverFeedReady? ready = state is DriverFeedReady ? state : null;
    final DriverFeedFailed? failed = state is DriverFeedFailed ? state : null;
    final loading = state is DriverFeedLoading || state is DriverFeedIdle;

    return DriverPageFrame(
      title: l10n.driverOpenRequests,
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
                label: l10n.driverOpenJobDetails,
                trailingIcon: DealGoIcons.arrowRight,
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
          DriverPanel(
            elevated: true,
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        l10n.driverServicesAreaSection,
                        style: textTheme.bodySmall,
                      ),
                      const SizedBox(height: DealGoSpacing.s4),
                      Text(
                        driverServicesSummary(l10n, services),
                        key: const Key('driver-jobs-services'),
                        style: textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
                TextButton(
                  key: const Key('driver-jobs-open-services'),
                  onPressed: () => context.push(DriverRoutes.services),
                  child: Text(l10n.driverConfigure),
                ),
                DriverChip(
                  label: l10n.driverOnlineBadge,
                  tone: DriverChipTone.green,
                ),
              ],
            ),
          ),
          const SizedBox(height: DealGoSpacing.s12),
          if (loading) const DealGoSkeletonList(itemCount: 3),
          if (failed != null)
            DealGoStateView.failure(
              context,
              onRetry: onRetry,
              cause: failed.sessionExpired ? sessionExpiredFailure : failed.error,
              message: failed.sessionExpired
                  ? l10n.errorSessionExpired
                  : apiErrorText(
                      l10n,
                      failed.error,
                      fallback: l10n.driverLoadRequestsFailed,
                    ),
              compact: true,
            ),
          if (ready != null && ready.rides.isEmpty && ready.food.isEmpty)
            DealGoStateView(
              art: DealGoStateArt.noOrders,
              title: services.rideEnabled || services.foodEnabled
                  ? l10n.driverNoOpenRequests
                  : l10n.driverServicesNoneOn,
              compact: true,
            ),
          if (ready != null && ready.rides.isNotEmpty) ...[
            Text(l10n.driverRidesAvailable, style: textTheme.titleMedium),
            const SizedBox(height: DealGoSpacing.s8),
            for (final ride in ready.rides) ...[
              _RideJobCard(ride: ride),
              const SizedBox(height: DealGoSpacing.s12),
            ],
          ],
          if (ready != null && ready.food.isNotEmpty) ...[
            Text(l10n.driverFoodAvailable, style: textTheme.titleMedium),
            const SizedBox(height: DealGoSpacing.s8),
            for (final job in ready.food) ...[
              _FoodJobCard(job: job),
              const SizedBox(height: DealGoSpacing.s12),
            ],
          ],
          DriverNote(
            tone: DriverNoteTone.green,
            message: l10n.driverOneJobNote,
          ),
          const SizedBox(height: DealGoSpacing.s16),
          Text(
            AppLocalizations.of(context).driverJobsHistorySection,
            style: textTheme.titleMedium,
          ),
          const SizedBox(height: DealGoSpacing.s8),
          TextButton(
            key: const Key('driver-open-history'),
            onPressed: () => context.go('/driver/earnings'),
            child: Text(AppLocalizations.of(context).driverOpenHistory),
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
      elevated: true,
      borderColor: DealGoColors.primary.withValues(alpha: 0.35),
      child: InkWell(
        key: Key('driver-ride-${ride.id}'),
        onTap: () => context.push(DriverRoutes.ride(ride.id), extra: ride),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    AppLocalizations.of(context).rideRef(shortRef(ride.id)),
                    style: textTheme.titleSmall,
                  ),
                ),
                DriverChip(
                  label: AppLocalizations.of(context).driverRideChip,
                  tone: DriverChipTone.green,
                ),
              ],
            ),
            const SizedBox(height: DealGoSpacing.s12),
            Text(ride.pickup.label, style: textTheme.titleMedium),
            Text(ride.dropoff.label, style: textTheme.bodySmall),
            const SizedBox(height: DealGoSpacing.s12),
            DriverMoneyRow(
              label: AppLocalizations.of(context).driverCustomerFare,
              value: formatRideVnd(ride.offeredFareVnd),
              emphasize: true,
            ),
            DriverMoneyRow(
              label: AppLocalizations.of(context).driverReferenceFare,
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
    final l10n = AppLocalizations.of(context);
    return DriverPanel(
      elevated: true,
      borderColor: DealGoColors.primary.withValues(alpha: 0.35),
      child: InkWell(
        key: Key('driver-food-${job.id}'),
        onTap: () => context.push(DriverRoutes.food(job.id), extra: job),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    l10n.orderRef(shortRef(job.id)),
                    style: textTheme.titleSmall,
                  ),
                ),
                DriverChip(
                  label: l10n.driverServicesFoodTitle,
                  tone: DriverChipTone.green,
                ),
              ],
            ),
            const SizedBox(height: DealGoSpacing.s12),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                DecoratedBox(
                  decoration: BoxDecoration(
                    color: DealGoColors.subtlePurple,
                    borderRadius: BorderRadius.circular(DealGoRadius.input),
                  ),
                  child: const SizedBox(
                    width: 48,
                    height: 48,
                    child: Icon(DealGoIcons.store, color: DealGoColors.primary),
                  ),
                ),
                const SizedBox(width: DealGoSpacing.s12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        job.storeName ?? l10n.driverPickupStore,
                        style: textTheme.titleMedium,
                      ),
                      if (job.storeAddress != null)
                        Text(job.storeAddress!, style: textTheme.bodySmall),
                      Text(
                        l10n.driverFoodJobSummary(
                          job.lineCount,
                          job.dropoff.label,
                        ),
                        style: textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: DealGoSpacing.s12),
            DriverMoneyRow(
              label: l10n.driverDeliveryFare,
              value: formatVnd(job.deliveryFareVnd),
              emphasize: true,
            ),
            Text(
              l10n.driverDeliveryFareNote,
              style: textTheme.bodySmall?.copyWith(
                color: DealGoColors.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
