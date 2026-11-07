import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/notifications/notification_router.dart';
import '../../../../core/realtime/snapshot_realtime.dart';
import '../../../../core/design_system/components/dealgo_primary_button.dart';
import '../../../../core/design_system/components/dealgo_skeleton.dart';
import '../../../../core/design_system/components/dealgo_state_view.dart';
import '../../../../core/design_system/tokens/dealgo_tokens.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../food/domain/entities/food_money.dart';
import '../../../food/domain/entities/food_models.dart';
import '../../../parcel/presentation/widgets/parcel_labels.dart';
import '../../../ride/domain/entities/ride_models.dart';
import '../../../ride/presentation/utils/ride_vehicle_label.dart';
import '../../../ride/presentation/widgets/ride_negotiation_ui.dart'
    show customerRatingText;
import '../../../ride/domain/entities/ride_money.dart';
import '../../../onboarding/presentation/cubit/driver_kyc_cubit.dart';
import '../cubit/driver_duty_cubit.dart';
import '../cubit/driver_feed_cubit.dart';
import '../cubit/driver_services_cubit.dart';
import 'driver_home_page.dart';
import '../../../ride/presentation/cubit/vehicle_class_catalog_cubit.dart';
import '../utils/driver_routes.dart';
import '../utils/driver_service_icons.dart';
import '../widgets/driver_service_strip.dart';
import '../widgets/driver_widgets.dart';
import '../widgets/driver_inline_quote.dart';
import '../widgets/driver_job_distance.dart';
import '../../../../core/design_system/icons/dealgo_icons.dart';
import '../../../../core/format/short_ref.dart';
import '../../../../core/l10n/api_error_text.dart';
import '../../../../core/network/request_failure.dart';
import '../../../../core/design_system/components/dealgo_nav_insets.dart';
import '../../../../core/design_system/components/dealgo_refresh.dart';

class DriverJobsPage extends StatefulWidget {
  const DriverJobsPage({super.key});

  @override
  State<DriverJobsPage> createState() => _DriverJobsPageState();
}

class _DriverJobsPageState extends State<DriverJobsPage> {
  // Back from the background (e.g. a "new ride nearby" push tapped while the app was
  // suspended): the list and any old error are from before, so ask again.
  late final AppLifecycleListener _lifecycle = AppLifecycleListener(
    onResume: _sync,
  );

  StreamSubscription<void>? _jobHints;
  StreamSubscription<void>? _reconnects;
  StreamSubscription<DriverJobPushTap>? _pushTaps;
  Timer? _hintDebounce;

  @override
  void initState() {
    super.initState();
    _lifecycle;
    final realtime = _maybeRealtime(context);
    if (realtime != null) {
      // A new ride / READY food job nearby: refresh within ~0.3 s instead of
      // waiting for the driver to pull or reopen the app.
      _jobHints = realtime.jobRequests.listen((_) => _quietSyncSoon());
      _reconnects = realtime.reconnects.listen((_) => _quietSyncSoon());
    }
    _pushTaps = driverJobPushTaps.listen(_onPushTap);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _sync();
      if (mounted) {
        context.read<DriverServicesCubit>().load();
        context.read<DriverKycCubit>().refresh();
        context.read<VehicleClassCatalogCubit>().load();
      }
    });
  }

  @override
  void dispose() {
    _hintDebounce?.cancel();
    unawaited(_jobHints?.cancel());
    unawaited(_reconnects?.cancel());
    unawaited(_pushTaps?.cancel());
    _lifecycle.dispose();
    super.dispose();
  }

  Future<void> _sync({bool quiet = false}) async {
    if (!mounted) {
      return;
    }
    await context.read<DriverFeedCubit>().sync(
      online: context.read<DriverDutyCubit>().state,
      accessToken: driverAccessToken(context),
      quiet: quiet,
    );
  }

  /// Tapped "Cuốc xe mới": read the list again (keeping what is on screen) and,
  /// when that job is no longer open (customer cancelled / another driver got
  /// it), say so instead of leaving the driver at an unexplained empty list.
  Future<void> _onPushTap(DriverJobPushTap tap) async {
    if (!mounted) {
      return;
    }
    final feed = context.read<DriverFeedCubit>();
    final messenger = ScaffoldMessenger.maybeOf(context);
    final gone = AppLocalizations.of(context).driverJobPushGone;
    await feed.sync(
      online: context.read<DriverDutyCubit>().state,
      accessToken: driverAccessToken(context),
      quiet: true,
    );
    final id = tap.jobId;
    if (!mounted || id == null || feed.state is! DriverFeedReady) {
      return;
    }
    if (openRideFrom(feed.state, id) == null &&
        readyFoodFrom(feed.state, id) == null) {
      messenger
        ?..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(key: const Key('driver-job-push-gone'), content: Text(gone)),
        );
    }
  }

  /// Bursts (several requests at once) collapse into one GET.
  void _quietSyncSoon() {
    _hintDebounce?.cancel();
    _hintDebounce = Timer(const Duration(milliseconds: 300), () {
      if (mounted && context.read<DriverDutyCubit>().state) {
        _sync(quiet: true);
      }
    });
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
      showBack: false,
      body: ListView(
        padding: dealGoScrollPadding(
          context,
          const EdgeInsets.all(DealGoDimensions.pageGutter),
        ),
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
  final Future<void> Function() onRetry;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final l10n = AppLocalizations.of(context);
    final services = context.watch<DriverServicesCubit>().state.saved;
    final vehicleClass = context.select<DriverKycCubit, String?>(
      (cubit) => cubit.state.vehicleClassCode,
    );
    final state = feed;
    final DriverFeedReady? ready = state is DriverFeedReady ? state : null;
    final DriverFeedFailed? failed = state is DriverFeedFailed ? state : null;
    final loading = state is DriverFeedLoading || state is DriverFeedIdle;

    return DriverPageFrame(
      title: l10n.driverOpenRequests,
      showBack: false,
      footer: ready == null || (ready.rides.isEmpty && ready.food.isEmpty)
          ? null
          : Padding(
              padding: const EdgeInsets.fromLTRB(
                DealGoDimensions.pageGutter,
                DealGoSpacing.s8,
                DealGoDimensions.pageGutter,
                DealGoSpacing.s12,
              ),
              child: DealGoPrimaryButton(
                key: const Key('driver-open-first-job'),
                label: l10n.driverOpenJobDetails,
                trailingIcon: DealGoIcons.arrowRight,
                onPressed: () => _openFirst(context, ready),
              ),
            ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(
              DealGoDimensions.pageGutter,
              DealGoSpacing.s8,
              DealGoDimensions.pageGutter,
              DealGoSpacing.s8,
            ),
            child: DriverPanel(
              elevated: true,
              padding: const EdgeInsets.fromLTRB(
                DealGoSpacing.s12,
                DealGoSpacing.s4,
                DealGoSpacing.s4,
                DealGoSpacing.s12,
              ),
              child: DriverServiceStrip(
                key: const Key('driver-jobs-services'),
                prefs: services,
                vehicleClassCode: vehicleClass,
                showStatus: true,
                online: true,
                settingsKey: const Key('driver-jobs-open-services'),
                onOpenSettings: () => context.push(DriverRoutes.services),
                pillKeyFor: (kind) => Key('driver-jobs-service-${kind.name}'),
              ),
            ),
          ),
          Expanded(
            child: DealGoRefresh(
              onRefresh: onRetry,
              child: loading
                  ? const DealGoSkeletonList(itemCount: 3)
                  : failed != null
                  ? DealGoStateView.failure(
                      context,
                      onRetry: onRetry,
                      cause: failed.sessionExpired
                          ? sessionExpiredFailure
                          : failed.error,
                      message: failed.sessionExpired
                          ? l10n.errorSessionExpired
                          : apiErrorText(
                              l10n,
                              failed.error,
                              fallback: l10n.driverLoadRequestsFailed,
                            ),
                    )
                  : (ready != null && ready.rides.isEmpty && ready.food.isEmpty)
                  ? DealGoStateView(
                      art: DealGoStateArt.noOrders,
                      title: driverEnabledServiceCount(services, vehicleClass) > 0
                          ? l10n.driverNoOpenRequests
                          : l10n.driverServicesNoneOn,
                    )
                  : ListView(
                      padding: dealGoScrollPadding(
                        context,
                        const EdgeInsets.fromLTRB(
                          DealGoDimensions.pageGutter,
                          0,
                          DealGoDimensions.pageGutter,
                          DealGoSpacing.s16,
                        ),
                      ),
                      children: [
                        if (ready != null && ready.rides.isNotEmpty) ...[
                          Text(
                            '${l10n.driverRidesAvailable} · ${ready.rides.length}',
                            style: textTheme.titleSmall,
                          ),
                          const SizedBox(height: DealGoSpacing.s8),
                          for (final ride in ready.rides) ...[
                            _RideJobCard(ride: ride),
                            const SizedBox(height: DealGoSpacing.s8),
                          ],
                        ],
                        if (ready != null && ready.food.isNotEmpty) ...[
                          Text(
                            l10n.driverFoodAvailable,
                            style: textTheme.titleMedium,
                          ),
                          const SizedBox(height: DealGoSpacing.s8),
                          for (final job in ready.food) ...[
                            _FoodJobCard(job: job),
                            const SizedBox(height: DealGoSpacing.s12),
                          ],
                        ],
                        Text(
                          AppLocalizations.of(context).driverJobsHistorySection,
                          style: textTheme.titleMedium,
                        ),
                        const SizedBox(height: DealGoSpacing.s8),
                        TextButton(
                          key: const Key('driver-open-history'),
                          onPressed: () => context.go('/driver/earnings'),
                          child: Text(
                            AppLocalizations.of(context).driverOpenHistory,
                          ),
                        ),
                      ],
                    ),
            ),
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

/// Compact job card so 2+ fit per screen — one header line,
/// pickup → drop-off on two ellipsized lines, customer price big with the
/// reference small, rating inline, then the inline quote. Tap opens details.
class _RideJobCard extends StatelessWidget {
  const _RideJobCard({required this.ride});

  final OpenRide ride;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final l10n = AppLocalizations.of(context);
    final muted = textTheme.bodySmall?.copyWith(
      color: DealGoColors.textSecondary,
    );
    return DriverPanel(
      elevated: true,
      padding: const EdgeInsets.fromLTRB(
        DealGoSpacing.s12,
        DealGoSpacing.s8,
        DealGoSpacing.s12,
        DealGoSpacing.s12,
      ),
      child: InkWell(
        key: Key('driver-ride-${ride.id}'),
        onTap: () => context.push(DriverRoutes.ride(ride.id), extra: ride),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                if (ride.isParcel)
                  const Icon(
                    DriverServiceIcons.parcel,
                    size: 16,
                    color: DealGoColors.primary,
                  )
                else
                  DriverVehicleVisual(
                    vehicleClassCode: ride.vehicleClassCode,
                    imageUrl: ride.imageUrl,
                    size: 16,
                  ),
                const SizedBox(width: DealGoSpacing.s4),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    l10n.rideRef(shortRef(ride.id)),
                    key: Key('driver-ride-ref-${ride.id}'),
                    style: textTheme.labelLarge?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                    maxLines: 1,
                    softWrap: false,
                  ),
                ),
                const SizedBox(width: DealGoSpacing.s8),
                Flexible(
                  child: Text(
                    ride.isParcel
                        ? parcelBadgeText(
                            l10n,
                            ride.parcelSizeClass,
                            ride.parcelWeightKg,
                          )
                        : rideVehicleClassName(context, ride.vehicleClassCode),
                    key: ride.isParcel
                        ? Key('driver-job-parcel-${ride.id}')
                        : null,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: muted,
                  ),
                ),
                if (ride.intercity) ...[
                  const SizedBox(width: DealGoSpacing.s4),
                  DriverChip(
                    key: Key('driver-job-intercity-${ride.id}'),
                    label: l10n.rideIntercity,
                    tone: DriverChipTone.warning,
                  ),
                ],
              ],
            ),
            const SizedBox(height: DealGoSpacing.s8),
            _RouteLine(
              icon: DealGoIcons.pin,
              color: DealGoColors.primary,
              text: ride.pickup.label,
              style: textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            _RouteLine(
              icon: DealGoIcons.navigation,
              color: DealGoColors.danger,
              text: ride.dropoff.label,
              style: textTheme.bodyMedium,
            ),
            if (ride.stops.isNotEmpty)
              Text(
                l10n.rideStopsCount(ride.stops.length),
                key: Key('driver-job-stops-${ride.id}'),
                style: textTheme.labelSmall?.copyWith(
                  color: DealGoColors.amber,
                ),
              ),
            // t82u: trip length + how far the pickup is from me.
            DriverJobDistanceRow(ride: ride),
            const SizedBox(height: DealGoSpacing.s8),
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Text(
                  formatRideVnd(ride.offeredFareVnd),
                  key: Key('driver-job-fare-${ride.id}'),
                  style: textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w800,
                    color: DealGoColors.text,
                  ),
                ),
                const SizedBox(width: DealGoSpacing.s8),
                Flexible(
                  child: Text(
                    '${l10n.driverReferenceFare} ${formatRideVnd(ride.referenceFareVnd)}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: muted,
                  ),
                ),
                const SizedBox(width: DealGoSpacing.s8),
                // Like inDrive, the rider's rating shows before the driver opens the request.
                Row(
                  key: Key('driver-open-customer-rating-${ride.id}'),
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      DealGoIcons.starFilled,
                      size: 14,
                      color: DealGoColors.amber,
                    ),
                    const SizedBox(width: 2),
                    Text(
                      customerRatingText(l10n, ride.customerRating),
                      style: textTheme.labelSmall,
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: DealGoSpacing.s8),
            DriverInlineQuote(
              key: ValueKey('job-quote-${ride.id}'),
              ride: ride,
            ),
          ],
        ),
      ),
    );
  }
}

class _RouteLine extends StatelessWidget {
  const _RouteLine({
    required this.icon,
    required this.color,
    required this.text,
    this.style,
  });

  final IconData icon;
  final Color color;
  final String text;
  final TextStyle? style;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 1),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 3),
            child: Icon(icon, size: 14, color: color),
          ),
          const SizedBox(width: DealGoSpacing.s4),
          Expanded(
            child: Text(
              text,
              // t82u (owner): two lines so addresses read in full.
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: style,
            ),
          ),
        ],
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
      padding: const EdgeInsets.all(DealGoSpacing.s12),
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
                const Icon(
                  DriverServiceIcons.food,
                  size: 16,
                  color: DealGoColors.primary,
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
          ],
        ),
      ),
    );
  }
}

SnapshotRealtime? _maybeRealtime(BuildContext context) {
  try {
    return context.read<SnapshotRealtime>();
  } catch (_) {
    return null;
  }
}
