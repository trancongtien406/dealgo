import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/design_system/tokens/dealgo_tokens.dart';
import '../../../../core/maps/map_lat_lng.dart';
import '../../../../core/maps/map_markers.dart';
import '../../../../core/maps/map_port.dart';
import '../../../../core/network/api_exception.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../food/presentation/widgets/food_fare_widgets.dart';
import '../../../food/data/food_fare_negotiation.dart';
import '../../../../core/realtime/realtime_refresh_watcher.dart';
import '../../../../core/realtime/snapshot_realtime.dart';
import '../../../food/domain/entities/food_models.dart';
import '../../../live_location/domain/driver_location.dart';
import '../../../live_location/presentation/server_phase_route.dart';
import '../../../food/domain/entities/food_money.dart';
import '../../../food/domain/params/food_delivery_action.dart';
import '../../domain/usecases/advance_food_delivery.dart';
import '../../domain/usecases/claim_food_order.dart';
import '../utils/driver_action_runner.dart';
import '../cubit/driver_duty_cubit.dart';
import '../cubit/driver_feed_cubit.dart';
import '../cubit/driver_food_cubit.dart';
import '../utils/driver_routes.dart';
import '../widgets/driver_navigate_buttons.dart';
import '../widgets/driver_food_code_sheet.dart';
import '../../../ride/presentation/widgets/ride_negotiation_ui.dart';
import '../widgets/driver_widgets.dart';
import '../widgets/driver_payment_collection.dart';
import '../../../../core/design_system/components/handover_ref_badge.dart';
import '../../../../core/design_system/icons/dealgo_icons.dart';
import '../../../../core/format/short_ref.dart';
import '../../../../core/l10n/api_error_text.dart';
import '../widgets/driver_contact_actions.dart';
import '../widgets/job_customer_name.dart';
import '../../../food/presentation/widgets/food_order_extras.dart';

/// Poll fallback for the open offer screen (socket hints are primary).
const driverOfferPollInterval = Duration(seconds: 8);

enum DriverOfferOutcome { open, selected, notChosen }

/// What the driver's own offers say: chosen → assigned; lost or the fee was
/// agreed with someone else → not chosen; otherwise still open.
DriverOfferOutcome driverOfferOutcome(FoodDeliveryOffers offers) {
  if (offers.offers.any((o) => o.status == FoodDeliveryOfferStatus.selected)) {
    return DriverOfferOutcome.selected;
  }
  if (offers.offers.any((o) => o.status == FoodDeliveryOfferStatus.lost) ||
      offers.agreed) {
    return DriverOfferOutcome.notChosen;
  }
  return DriverOfferOutcome.open;
}

/// The job as the driver will run it once a counter is chosen: the agreed
/// fee replaces the posted one and COD moves by the same difference.
ReadyFoodJob withAgreedFare(ReadyFoodJob job, int agreedFareVnd) {
  if (agreedFareVnd <= 0 || agreedFareVnd == job.deliveryFareVnd) return job;
  return ReadyFoodJob(
    id: job.id,
    storeId: job.storeId,
    deliveryFareVnd: agreedFareVnd,
    subtotalVnd: job.subtotalVnd,
    totalVnd: job.totalVnd - job.deliveryFareVnd + agreedFareVnd,
    dropoff: job.dropoff,
    lineCount: job.lineCount,
    storeName: job.storeName,
    storeAddress: job.storeAddress,
    pickup: job.pickup,
    route: job.route,
    approachRoute: job.approachRoute,
    note: job.note,
    utensils: job.utensils,
  );
}

enum _FoodPhase { offer, navigate, wait, pickup, deliver, complete }

/// Phase to reopen a claimed delivery on (relaunch / deep link).
_FoodPhase _resumePhase(String status) =>
    status == 'PICKED_UP' ? _FoodPhase.deliver : _FoodPhase.navigate;

class DriverFoodDetailPage extends StatelessWidget {
  const DriverFoodDetailPage({required this.job, this.resumed, super.key});

  final ReadyFoodJob job;

  /// Set when the driver already holds this order (ASSIGNED / PICKED_UP):
  /// the page opens straight on the delivery lifecycle.
  final ClaimedFoodDelivery? resumed;

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) =>
          DriverFoodCubit(claimFoodOrder: context.read<ClaimFoodOrder>()),
      child: _DriverFoodDetailView(job: job, resumed: resumed),
    );
  }
}

class _DriverFoodDetailView extends StatefulWidget {
  const _DriverFoodDetailView({required this.job, this.resumed});

  final ReadyFoodJob job;
  final ClaimedFoodDelivery? resumed;

  @override
  State<_DriverFoodDetailView> createState() => _DriverFoodDetailPageState();
}

class _DriverFoodDetailPageState extends State<_DriverFoodDetailView>
    with DriverActionRunner {
  var _claiming = false;
  var _taken = false;
  var _notChosen = false;
  var _phase = _FoodPhase.offer;
  String? _error;
  ClaimedFoodDelivery? _claimed;
  RealtimeRefreshWatcher? _watcher;
  Timer? _poll;

  @override
  void initState() {
    super.initState();
    if (widget.resumed == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _watchOffer());
    }
    final resumed = widget.resumed;
    if (resumed != null) {
      _claimed = resumed;
      _phase = _resumePhase(resumed.status);
      // Back on duty so presence + DriverLocationReporter keep streaming GPS.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          ensureDriverOnDuty(context);
        }
      });
    }
  }

  /// While the offer screen is open, follow the order live: the server sends
  /// a `snapshot` hint to this driver's private room on select / assign /
  /// LOST; a poll is the fallback when the socket is down.
  void _watchOffer() {
    if (!mounted) return;
    final token = driverAccessToken(context);
    if (token == null || token.isEmpty) return;
    SnapshotRealtime? realtime;
    try {
      realtime = context.read<SnapshotRealtime>();
    } on ProviderNotFoundException {
      realtime = null;
    }
    if (realtime != null) {
      final watcher = RealtimeRefreshWatcher(
        realtime: realtime,
        rooms: const [],
        refresh: _checkOffer,
        matchesSnapshot: (hint) =>
            hint.aggregateType == 'FoodOrder' &&
            hint.aggregateId == widget.job.id,
      );
      _watcher = watcher;
      unawaited(watcher.start(accessToken: token, initialRefresh: false));
    }
    _poll = Timer.periodic(driverOfferPollInterval, (_) => _checkOffer());
  }

  void _stopWatching() {
    _poll?.cancel();
    _poll = null;
    final watcher = _watcher;
    _watcher = null;
    if (watcher != null) unawaited(watcher.stop());
  }

  ReadyFoodJob? _agreedJob;

  Future<void> _checkOffer() async {
    if (!mounted || _claimed != null || _taken || _claiming) return;
    final client = maybeFoodFareClient(context);
    final token = driverAccessToken(context);
    if (client == null || token == null || token.isEmpty) return;
    FoodDeliveryOffers offers;
    try {
      offers = await client.list(accessToken: token, orderId: widget.job.id);
    } on ApiException {
      return;
    }
    if (!mounted || _claimed != null || _taken) return;
    switch (driverOfferOutcome(offers)) {
      case DriverOfferOutcome.selected:
        _stopWatching();
        setState(() {
          _claimed = ClaimedFoodDelivery(id: widget.job.id, status: 'ASSIGNED');
          _agreedJob = withAgreedFare(widget.job, offers.deliveryFareVnd);
          _phase = _FoodPhase.navigate;
        });
        ensureDriverOnDuty(context);
      case DriverOfferOutcome.notChosen:
        _stopWatching();
        setState(() {
          _taken = true;
          _notChosen = true;
        });
      case DriverOfferOutcome.open:
        break;
    }
  }

  @override
  void dispose() {
    _stopWatching();
    super.dispose();
  }

  Future<void> _claim() async {
    if (_claiming || _taken || _claimed != null) {
      return;
    }
    final token = driverAccessToken(context);
    if (token == null || token.isEmpty) {
      setState(() => _error = AppLocalizations.of(context).errorSessionExpired);
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
        _error = apiErrorText(AppLocalizations.of(context), error);
      });
    } catch (_) {
      if (!mounted) {
        return;
      }
      setState(() {
        _claiming = false;
        _error = AppLocalizations.of(context).driverClaimFailed;
      });
    }
  }

  /// Pickup and deliver hit the backend; the store/customer arrival steps are
  /// on-device only (the API has no such states).
  Future<void> _goTo(_FoodPhase next) async {
    final action = switch (next) {
      _FoodPhase.pickup => FoodDeliveryAction.pickup,
      _FoodPhase.complete => FoodDeliveryAction.deliver,
      _ => null,
    };
    if (action == null) {
      setState(() {
        actionError = null;
        _phase = next;
      });
      return;
    }
    final advance = context.read<AdvanceFoodDelivery>();
    // DEC-PROD-036: when the server asks for a delivery / handover code, prompt and retry.
    String? code;
    while (true) {
      ApiException? codePrompt;
      final ok = await runDriverAction((token) async {
        try {
          final updated = await advance(
            accessToken: token,
            orderId: widget.job.id,
            action: action,
            code: code,
          );
          _claimed = updated;
        } on ApiException catch (error) {
          final errorCode = error.errorCode;
          if (errorCode.endsWith('_CODE_REQUIRED') ||
              errorCode.endsWith('_CODE_INVALID')) {
            codePrompt = error;
            return;
          }
          rethrow;
        }
      });
      if (!mounted) {
        return;
      }
      final prompt = codePrompt;
      if (prompt == null) {
        if (ok) {
          // After pickup go straight to "deliver": no extra "arrived at
          // customer" tap; the delivery code is still asked on complete.
          setState(
            () =>
                _phase = next == _FoodPhase.pickup ? _FoodPhase.deliver : next,
          );
        }
        return;
      }
      final l10n = AppLocalizations.of(context);
      code = await showDriverFoodCodeSheet(
        context,
        delivery: action == FoodDeliveryAction.deliver,
        error: prompt.errorCode.endsWith('_INVALID')
            ? l10n.driverFoodCodeWrong
            : null,
      );
      if (code == null || !mounted) {
        return;
      }
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
      return _JobTaken(
        job: widget.job,
        onRefresh: _refreshFeed,
        notChosen: _notChosen,
      );
    }
    if (_phase != _FoodPhase.offer && _claimed != null) {
      return _FoodLifecycle(
        job: _agreedJob ?? widget.job,
        claimed: _claimed!,
        phase: _phase,
        busy: actionBusy,
        error: actionError,
        onPhase: _goTo,
        onBack: () => driverBack(context),
      );
    }
    final l10n = AppLocalizations.of(context);
    final textTheme = Theme.of(context).textTheme;
    final job = widget.job;
    return Scaffold(
      body: DriverPageFrame(
        title: l10n.driverFoodRequestTitle,
        insetBottom: true,
        onBack: () => driverBack(context),
        footer: DriverFooter(
          secondaryLabel: l10n.actionSkip,
          primaryLabel: l10n.driverClaimJob,
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
                  Text(l10n.driverJobInfo, style: textTheme.titleMedium),
                  const SizedBox(height: DealGoSpacing.s8),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          l10n.orderRef(shortRef(job.id)),
                          style: textTheme.bodyMedium?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      HandoverRefBadge(orderId: job.id, dense: true),
                      const SizedBox(width: DealGoSpacing.s8),
                      DriverChip(
                        label: l10n.driverItemsCount(job.lineCount),
                        tone: DriverChipTone.neutral,
                      ),
                    ],
                  ),
                  const SizedBox(height: DealGoSpacing.s12),
                  DriverMoneyRow(
                    label: l10n.driverFoodFeeCustomerPays,
                    value: formatVnd(job.deliveryFareVnd),
                    emphasize: true,
                  ),
                  DriverMoneyRow(
                    label: l10n.driverFoodExpectedIncome,
                    value: l10n.driverFoodIncomePending,
                    emphasize: true,
                  ),
                  DriverFareCounterButton(
                    orderId: job.id,
                    customerOfferVnd: job.deliveryFareVnd,
                    accessToken: driverAccessToken(context) ?? '',
                    enabled: !_claiming,
                  ),
                ],
              ),
            ),
            if ((job.note ?? '').trim().isNotEmpty || !job.utensils) ...[
              const SizedBox(height: DealGoSpacing.s12),
              DriverPanel(
                child: FoodOrderExtrasBlock(
                  note: job.note,
                  utensils: job.utensils,
                ),
              ),
            ],
            const SizedBox(height: DealGoSpacing.s12),
            DriverFoodJobMap(job: job),
            const SizedBox(height: DealGoSpacing.s12),
            DriverPanel(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(l10n.driverDeliveryStops, style: textTheme.titleMedium),
                  const SizedBox(height: DealGoSpacing.s12),
                  DriverStop(
                    color: DealGoColors.brandGreen,
                    label: l10n.driverPickupPoint,
                    value: <String>{
                      job.storeName ?? l10n.driverPickupStore,
                      ?(job.pickup?.label.isNotEmpty == true
                          ? job.pickup!.label
                          : job.storeAddress),
                    }.join(' · '),
                  ),
                  const SizedBox(height: DealGoSpacing.s12),
                  DriverStop(
                    color: DealGoColors.danger,
                    label: l10n.driverDropoffPoint,
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
                  Text(l10n.driverFinance, style: textTheme.titleMedium),
                  const SizedBox(height: DealGoSpacing.s8),
                  DriverMoneyRow(
                    label: l10n.driverFoodCodCollect,
                    value: formatVnd(job.totalVnd),
                    emphasize: true,
                  ),
                  DriverMoneyRow(
                    label: l10n.driverFoodSubtotal,
                    value: formatVnd(job.subtotalVnd),
                  ),
                  DriverMoneyRow(
                    label: l10n.driverFoodDeliveryFee,
                    value: formatVnd(job.deliveryFareVnd),
                  ),
                ],
              ),
            ),
            const SizedBox(height: DealGoSpacing.s12),
            DriverNote(
              tone: DriverNoteTone.green,
              message:
                  '${l10n.driverCodNote(formatVnd(job.totalVnd))} ${l10n.driverFoodNoClientFee}',
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

/// Hand a claimed order back before pickup; it returns to the pool.
Future<void> releaseClaimedFoodOrder(
  BuildContext context,
  String orderId,
) async {
  final client = maybeRideNegotiation(context);
  final token = driverAccessToken(context);
  if (client == null || token == null || token.isEmpty) {
    return;
  }
  final l10n = AppLocalizations.of(context);
  final reason = await showReasonSheet(
    context: context,
    title: l10n.driverFoodReleaseTitle,
    hint: l10n.driverFoodReleaseHint,
    reasons: foodReleaseReasons(l10n),
  );
  if (reason == null || !context.mounted) {
    return;
  }
  try {
    await client.releaseFoodOrder(
      accessToken: token,
      orderId: orderId,
      reason: reason,
    );
    if (!context.mounted) {
      return;
    }
    showNegotiationSnack(context, l10n.driverFoodReleaseDone);
    context.go('/driver/jobs');
  } catch (error) {
    if (context.mounted) {
      showNegotiationSnack(context, negotiationErrorText(context, error));
    }
  }
}

class _FoodLifecycle extends StatelessWidget {
  const _FoodLifecycle({
    required this.job,
    required this.claimed,
    required this.phase,
    required this.onPhase,
    required this.onBack,
    this.busy = false,
    this.error,
  });

  final ReadyFoodJob job;
  final ClaimedFoodDelivery claimed;
  final _FoodPhase phase;
  final ValueChanged<_FoodPhase> onPhase;
  final VoidCallback onBack;
  final bool busy;
  final String? error;

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
      _FoodPhase.offer => l10n.driverFoodRequestTitle,
    };
    final canRelease = maybeRideNegotiation(context) != null;
    final footer = switch (phase) {
      _FoodPhase.navigate => DriverFooter(
        secondaryLabel: canRelease
            ? l10n.driverFoodRelease
            : l10n.driverActiveReportIssue,
        secondaryKey: canRelease ? const Key('driver-food-release') : null,
        // Fewer taps: one button at the store both confirms arrival and the
        // pickup (handover code still enforced by the server).
        primaryLabel: l10n.driverFoodConfirmPickup,
        primaryKey: const Key('driver-food-pickup'),
        primaryLoading: busy,
        primaryEnabled: !busy,
        onSecondary: canRelease
            ? () => releaseClaimedFoodOrder(context, job.id)
            : () => context.push(DriverRoutes.failed(job.id)),
        onPrimary: () => onPhase(_FoodPhase.pickup),
      ),
      _FoodPhase.wait => DriverFooter(
        secondaryLabel: canRelease
            ? l10n.driverFoodRelease
            : l10n.driverActiveReportIssue,
        secondaryKey: canRelease ? const Key('driver-food-release') : null,
        primaryLabel: l10n.driverFoodConfirmPickup,
        primaryKey: const Key('driver-food-pickup'),
        primaryLoading: busy,
        primaryEnabled: !busy,
        onSecondary: canRelease
            ? () => releaseClaimedFoodOrder(context, job.id)
            : () => context.push(DriverRoutes.failed(job.id)),
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
        primaryLoading: busy,
        primaryEnabled: !busy,
        onSecondary: () =>
            context.push(DriverRoutes.failed(job.id, food: true)),
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
                  DealGoIcons.success,
                  size: 56,
                  color: DealGoColors.brandGreen,
                ),
              ),
              const SizedBox(height: DealGoSpacing.s12),
              Text(
                l10n.driverDeliveredTitle,
                textAlign: TextAlign.center,
                style: textTheme.titleLarge,
              ),
              Text(
                l10n.orderRef(shortRef(job.id)),
                textAlign: TextAlign.center,
                style: textTheme.bodySmall,
              ),
              const SizedBox(height: DealGoSpacing.s16),
            ],
            if (phase == _FoodPhase.navigate ||
                phase == _FoodPhase.deliver) ...[
              DriverPanel(
                color: const Color(0xFF1E1B4B),
                child: Row(
                  children: [
                    const Icon(DealGoIcons.turnRight, color: Colors.white),
                    const SizedBox(width: DealGoSpacing.s12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            phase == _FoodPhase.deliver
                                ? l10n.driverHeadToCustomer
                                : l10n.driverHeadToStore,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: textTheme.titleSmall?.copyWith(
                              color: Colors.white,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          Text(
                            phase == _FoodPhase.deliver
                                ? job.dropoff.label
                                : <String>{
                                    job.storeName ?? l10n.driverPickupStore,
                                    if (job.pickup?.label.isNotEmpty == true)
                                      job.pickup!.label,
                                  }.join(' · '),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
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
              DriverFoodJobMap(
                job: job,
                focusDropoff: phase == _FoodPhase.deliver,
                showNavigate: true,
              ),
              const SizedBox(height: DealGoSpacing.s12),
            ],
            if (phase == _FoodPhase.navigate ||
                phase == _FoodPhase.wait ||
                phase == _FoodPhase.pickup) ...[
              Center(child: HandoverRefBadge(orderId: job.id)),
              const SizedBox(height: DealGoSpacing.s12),
            ],
            // Same contact row as a ride: the customer may chat / call about the order.
            if (phase != _FoodPhase.offer && phase != _FoodPhase.complete) ...[
              DriverPanel(
                child: JobCustomerTile(
                  jobId: job.id,
                  isFood: true,
                  trailing: DriverContactActions(
                    resourceId: job.id,
                    isFood: true,
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
                        child: Text(
                          l10n.orderRef(shortRef(job.id)),
                          style: textTheme.titleMedium,
                        ),
                      ),
                      DriverChip(
                        label: switch (phase) {
                          _FoodPhase.navigate => l10n.driverHeadToStore,
                          _FoodPhase.wait => l10n.driverFoodPhaseWait,
                          _FoodPhase.pickup => l10n.driverFoodPhasePicked,
                          _FoodPhase.deliver => l10n.driverFoodPhaseDelivering,
                          _FoodPhase.complete => l10n.driverPhaseDone,
                          _FoodPhase.offer => l10n.driverClaimJob,
                        },
                        tone: DriverChipTone.green,
                      ),
                    ],
                  ),
                  const SizedBox(height: DealGoSpacing.s12),
                  DriverMoneyRow(
                    label: l10n.driverFoodDeliveryFee,
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
            DriverPaymentCollection(
              key: ValueKey('driver-food-collection-${phase.name}'),
              entityType: 'FOOD_ORDER',
              entityId: job.id,
              accessToken: driverAccessToken(context),
            ),
            const SizedBox(height: DealGoSpacing.s12),
            DriverNote(
              tone: DriverNoteTone.green,
              message: switch (phase) {
                _FoodPhase.navigate => l10n.driverFoodNavigateBody,
                _FoodPhase.wait => l10n.driverFoodWaitBody,
                _FoodPhase.pickup => l10n.driverFoodPickupBody,
                _FoodPhase.deliver => l10n.driverFoodDeliverBody,
                _FoodPhase.complete => l10n.driverFoodCompleteBody,
                _FoodPhase.offer => '',
              },
            ),
            if (error != null) ...[
              const SizedBox(height: DealGoSpacing.s12),
              DriverNote(message: error!),
            ],
          ],
        ),
      ),
    );
  }
}

class _JobTaken extends StatelessWidget {
  const _JobTaken({
    required this.job,
    required this.onRefresh,
    this.notChosen = false,
  });

  final ReadyFoodJob job;
  final bool notChosen;
  final Future<void> Function() onRefresh;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final textTheme = Theme.of(context).textTheme;
    return Scaffold(
      body: DriverPageFrame(
        title: l10n.driverNearbyRequests,
        insetBottom: true,
        onBack: () => driverBack(context),
        footer: DriverFooter(
          secondaryLabel: l10n.actionRefresh,
          primaryLabel: l10n.driverFindOtherJobs,
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
            DriverHero(
              icon: DealGoIcons.swapHoriz,
              iconColor: DealGoColors.amber,
              background: DealGoColors.amberSurface,
              title: notChosen
                  ? l10n.driverOfferNotChosenTitle
                  : l10n.driverJobTakenTitle,
              message: notChosen
                  ? l10n.driverOfferNotChosenBody
                  : l10n.driverJobTakenBody,
            ),
            const SizedBox(height: DealGoSpacing.s24),
            DriverPanel(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(l10n.driverJobUnavailable, style: textTheme.titleMedium),
                  const SizedBox(height: DealGoSpacing.s12),
                  DriverMoneyRow(label: l10n.driverRequestId, value: job.id),
                  DriverMoneyRow(
                    label: l10n.driverService,
                    value: l10n.driverServiceFood,
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

/// Store → customer map for a food job. Uses the pickup point snapshotted on
/// the order (DEC-PROD-034); without store coordinates only the customer pin is
/// drawn and a note asks the driver to follow the address.
class DriverFoodJobMap extends StatelessWidget {
  const DriverFoodJobMap({
    required this.job,
    this.focusDropoff = false,
    this.showNavigate = false,
    super.key,
  });

  final ReadyFoodJob job;
  final bool focusDropoff;

  /// Google Maps / Waze hand-off for the current stop (after claim only).
  final bool showNavigate;

  @override
  Widget build(BuildContext context) {
    final pickup = job.pickup;
    final dropoff = MapLatLng(lat: job.dropoff.lat, lng: job.dropoff.lng);
    final store = pickup == null
        ? null
        : MapLatLng(lat: pickup.lat, lng: pickup.lng);
    final center = focusDropoff || store == null ? dropoff : store;
    // Head to the store first; without a store point only the address helps.
    final target = focusDropoff ? dropoff : store;
    return Column(
      key: const Key('driver-food-map'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(DealGoRadius.card),
          child: SizedBox(
            height: 180,
            // Road path from Nest (DEC-PROD-045); none → markers only.
            // After claim: server phase leg (DEC-PROD-031 rev 3, DRAFT).
            child: ServerPhaseRoute(
              job: TrackedJob.food,
              id: job.id,
              active: showNavigate,
              approach: showNavigate && !focusDropoff,
              trip: job.route,
              approachSeed: job.approachRoute,
              builder: (context, route) => context.watch<MapPort>().buildMap(
                // Pins are bottom-anchored (~44 px tall): extra top room so they
                // never touch the card edge on the small inline map.
                fitPadding: const EdgeInsets.fromLTRB(36, 56, 36, 28),
                center: center,
                markers: [?store, dropoff],
                route: route,
                stopStyle: MapStopStyle.food,
                firstMarkerIsPickup: store != null,
              ),
            ),
          ),
        ),
        if (showNavigate && target != null) ...[
          const SizedBox(height: DealGoSpacing.s8),
          DriverNavigateButtons(
            lat: target.lat,
            lng: target.lng,
            destinationLabel: focusDropoff
                ? AppLocalizations.of(context).driverNavToCustomer
                : AppLocalizations.of(context).driverNavToStore,
          ),
        ],
        if (store == null) ...[
          const SizedBox(height: DealGoSpacing.s8),
          DriverNote(
            key: const Key('driver-food-no-store-point'),
            message: AppLocalizations.of(context).driverFoodNoStorePoint,
          ),
        ],
      ],
    );
  }
}
