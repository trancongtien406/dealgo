import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/config/api_base_url.dart';
import '../../../../core/design_system/components/dealgo_state_view.dart';
import '../../../../core/design_system/tokens/dealgo_tokens.dart';
import '../../../../core/network/request_failure.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../ride/domain/entities/ride_models.dart';
import '../../../ride/presentation/utils/ride_vehicle_label.dart';
import '../../../ride/presentation/widgets/ride_negotiation_ui.dart';
import '../../../../core/design_system/components/dealgo_dialog.dart';
import '../../../../core/design_system/components/dealgo_secondary_button.dart';
import '../../../ride/domain/entities/ride_money.dart';
import '../../../ride/domain/params/get_ride_params.dart';
import '../../../ride/domain/usecases/get_ride.dart';
import '../../../ride/domain/params/ride_driver_action.dart';
import '../../domain/usecases/advance_driver_ride.dart';
import '../cubit/driver_duty_cubit.dart';
import '../utils/driver_action_runner.dart';
import '../utils/driver_routes.dart';
import '../utils/ride_unassigned_copy.dart';
import '../widgets/driver_contact_actions.dart';
import '../widgets/job_customer_name.dart';
import '../widgets/driver_navigate_buttons.dart';
import '../widgets/driver_widgets.dart';
import '../../../../core/maps/map_lat_lng.dart';
import '../../../../core/maps/map_port.dart';
import '../../../live_location/domain/driver_location.dart';
import '../../../live_location/presentation/server_phase_route.dart';
import '../../../../core/design_system/icons/dealgo_icons.dart';
import '../../../../core/format/short_ref.dart';
import '../../../../core/realtime/realtime_refresh_watcher.dart';
import '../../../../core/realtime/snapshot_realtime.dart';

enum DriverRidePhase { navigatePickup, arrived, onTrip, complete }

DriverRidePhase parseDriverRidePhase(Object? raw) {
  return switch (raw) {
    'arrived' => DriverRidePhase.arrived,
    'onTrip' => DriverRidePhase.onTrip,
    'complete' => DriverRidePhase.complete,
    _ => DriverRidePhase.navigatePickup,
  };
}

/// D021–D025 — active ride lifecycle, driven by the backend trip state machine
/// (`POST /v1/rides/:id/{en-route,arrived,start,complete}`).
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

class _DriverActiveRidePageState extends State<DriverActiveRidePage>
    with DriverActionRunner {
  late DriverRidePhase _phase = widget.initialPhase;

  @visibleForTesting
  DriverRidePhase get debugPhase => _phase;

  /// Loaded from GET /v1/rides/:id when the page opens without ride data
  /// (deep link, notification, app restart). Never a made-up ride.
  OpenRide? _loaded;
  Object? _loadFailure;

  /// DEC-PROD-024: customer voucher on this ride; the driver collects fare minus this.
  var _discountVnd = 0;

  /// True once the backend has the ride in DRIVER_EN_ROUTE or later.
  late bool _enRoute =
      widget.ride?.status != null &&
      widget.ride!.status != 'ASSIGNED' &&
      widget.ride!.status != 'NEGOTIATING';

  @override
  void initState() {
    super.initState();
    // Always read the server ride: the job card has no voucher, the cash to collect does.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ensureDriverOnDuty(context);
      _load();
      _watchServer();
    });
  }

  RealtimeRefreshWatcher? _watcher;

  /// Server status changes (customer cancel, ops/API advance) reach this
  /// screen through the `ride:{id}` snapshot room; each hint re-GETs the ride.
  void _watchServer() {
    final token = driverAccessToken(context);
    SnapshotRealtime? realtime;
    try {
      realtime = context.read<SnapshotRealtime>();
    } catch (_) {
      realtime = null;
    }
    if (token == null || token.isEmpty || realtime == null) {
      return;
    }
    final watcher = RealtimeRefreshWatcher(
      realtime: realtime,
      rooms: [RideSnapshotRoom(widget.rideId)],
      refresh: _load,
      matchesSnapshot: (hint) =>
          hint.aggregateId == widget.rideId &&
          hint.aggregateType.toLowerCase().contains('ride'),
    );
    _watcher = watcher;
    unawaited(watcher.start(accessToken: token, initialRefresh: false));
  }

  @override
  void dispose() {
    final watcher = _watcher;
    if (watcher != null) {
      unawaited(watcher.stop());
    }
    super.dispose();
  }

  Future<void> _load() async {
    final token = driverAccessToken(context);
    final hasCard = widget.ride != null;
    if (token == null || token.isEmpty) {
      if (!hasCard) {
        setState(() => _loadFailure = sessionExpiredFailure);
      }
      return;
    }
    setState(() => _loadFailure = null);
    try {
      final view = await context.read<GetRide>()(
        GetRideParams(accessToken: token, rideId: widget.rideId),
      );
      if (!mounted) {
        return;
      }
      if (view.status == RideStatus.cancelled ||
          view.status == RideStatus.expired) {
        final l10n = AppLocalizations.of(context);
        ScaffoldMessenger.maybeOf(
          context,
        )?.showSnackBar(SnackBar(content: Text(l10n.inboxRideCancelledTitle)));
        context.go(DriverRoutes.services);
        return;
      }
      // start/arrive timeout or ops reassign put the ride back to
      // bidding with no driver: it is no longer this driver's job.
      if (view.status == RideStatus.negotiating &&
          view.assignedDriverId == null) {
        final l10n = AppLocalizations.of(context);
        ScaffoldMessenger.maybeOf(context)?.showSnackBar(
          SnackBar(content: Text(rideUnassignedMessage(l10n, ''))),
        );
        context.go('/driver/jobs');
        return;
      }
      setState(() {
        _loaded = openRideFromView(view);
        _discountVnd = view.discountVnd;
        _enRoute =
            view.status != RideStatus.assigned &&
            view.status != RideStatus.negotiating;
        _phase = driverPhaseForStatus(view.status) ?? _phase;
      });
    } catch (error) {
      if (mounted && !hasCard) {
        setState(() => _loadFailure = error);
      }
    }
  }

  Future<void> _advance(
    List<RideDriverAction> actions,
    DriverRidePhase next,
  ) async {
    final advance = context.read<AdvanceDriverRide>();
    final ok = await runDriverAction((token) async {
      for (final action in actions) {
        await advance(
          accessToken: token,
          rideId: widget.rideId,
          action: action,
        );
        if (action == RideDriverAction.enRoute) {
          _enRoute = true;
        }
      }
    });
    if (ok && mounted) {
      setState(() => _phase = next);
      // Fewer taps: "Đã đến" opens the pickup-OTP pad straight away, and
      // "Hoàn thành" lands on the summary (the OTP itself is still required).
      final ride = _loaded ?? widget.ride;
      if (next == DriverRidePhase.arrived) {
        context.push(DriverRoutes.passengerOtp(widget.rideId), extra: ride);
      } else if (next == DriverRidePhase.complete) {
        context.pushReplacement(DriverRoutes.completed(widget.rideId));
      }
    }
  }

  /// Runs a lifecycle command that closes the ride for this
  /// driver, then leaves the screen.
  Future<void> _closeRide(
    Future<void> Function(String token) command,
    String doneMessage,
  ) async {
    final token = driverAccessToken(context);
    if (actionBusy || token == null || token.isEmpty) {
      return;
    }
    setState(() {
      actionBusy = true;
      actionError = null;
    });
    try {
      await command(token);
      if (!mounted) {
        return;
      }
      setState(() => actionBusy = false);
      showNegotiationSnack(context, doneMessage);
      context.go(DriverRoutes.services);
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        actionBusy = false;
        actionError = negotiationErrorText(context, error);
      });
    }
  }

  /// Cancel an accepted ride with a reason (before the trip starts).
  Future<void> _driverCancel() async {
    final client = maybeRideNegotiation(context);
    if (client == null) {
      return;
    }
    final l10n = AppLocalizations.of(context);
    final reason = await showReasonSheet(
      context: context,
      title: l10n.driverCancelReasonTitle,
      hint: l10n.driverCancelHint,
      reasons: driverCancelReasons(l10n),
    );
    if (reason == null || !mounted) {
      return;
    }
    await _closeRide(
      (token) => client.driverCancel(
        accessToken: token,
        rideId: widget.rideId,
        reason: reason,
      ),
      l10n.driverCancelDone,
    );
  }

  /// Customer no-show after the server-side wait.
  Future<void> _noShow() async {
    final client = maybeRideNegotiation(context);
    if (client == null) {
      return;
    }
    final l10n = AppLocalizations.of(context);
    final confirmed = await showDealGoConfirmDialog(
      context: context,
      title: l10n.driverNoShow,
      body: l10n.driverNoShowBody,
      confirmLabel: l10n.driverNoShow,
      cancelLabel: l10n.actionBack,
      confirmTone: DealGoDialogPrimaryTone.danger,
      confirmKey: const Key('driver-no-show-confirm'),
    );
    if (!confirmed || !mounted) {
      return;
    }
    await _closeRide(
      (token) => client.markNoShow(accessToken: token, rideId: widget.rideId),
      l10n.driverNoShowDone,
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final textTheme = Theme.of(context).textTheme;
    final ride = _loaded ?? widget.ride;
    final canCancel = maybeRideNegotiation(context) != null;
    if (ride == null) {
      return DriverPageFrame(
        title: l10n.driverActiveNavTitle,
        insetBottom: true,
        onBack: () => driverBack(context),
        body: _loadFailure != null
            ? DealGoStateView.failure(
                context,
                key: const Key('driver-active-retry'),
                onRetry: _load,
                cause: _loadFailure,
                message: l10n.driverRideLoadFailed,
              )
            : const Center(child: CircularProgressIndicator()),
      );
    }
    final title = switch (_phase) {
      DriverRidePhase.navigatePickup => l10n.driverActiveNavTitle,
      DriverRidePhase.arrived => l10n.driverActiveArrivedTitle,
      DriverRidePhase.onTrip => l10n.driverActiveOnTripTitle,
      DriverRidePhase.complete => l10n.driverActiveCompleteTitle,
    };
    final footer = switch (_phase) {
      DriverRidePhase.navigatePickup => DriverFooter(
        secondaryLabel: canCancel
            ? l10n.driverCancelRide
            : l10n.driverActiveReportIssue,
        secondaryKey: canCancel ? const Key('driver-cancel-ride') : null,
        primaryLabel: l10n.driverActiveArrivedCta,
        primaryKey: const Key('driver-active-arrived'),
        primaryLoading: actionBusy,
        primaryEnabled: !actionBusy,
        onSecondary: canCancel
            ? _driverCancel
            : () => context.push(DriverRoutes.failed(widget.rideId)),
        onPrimary: () => _advance([
          if (!_enRoute) RideDriverAction.enRoute,
          RideDriverAction.arrived,
        ], DriverRidePhase.arrived),
      ),
      DriverRidePhase.arrived => DriverFooter(
        secondaryLabel: canCancel
            ? l10n.driverCancelRide
            : l10n.driverActiveReportIssue,
        secondaryKey: canCancel ? const Key('driver-cancel-ride') : null,
        primaryLabel: l10n.driverActiveOpenOtp,
        primaryKey: const Key('driver-active-open-otp'),
        onSecondary: canCancel
            ? _driverCancel
            : () => context.push(DriverRoutes.failed(widget.rideId)),
        onPrimary: () =>
            context.push(DriverRoutes.passengerOtp(widget.rideId), extra: ride),
      ),
      DriverRidePhase.onTrip => DriverFooter(
        secondaryLabel: l10n.driverActiveReportIssue,
        primaryLabel: l10n.driverActiveCompleteCta,
        primaryKey: const Key('driver-active-complete'),
        primaryLoading: actionBusy,
        primaryEnabled: !actionBusy,
        onSecondary: () => context.push(DriverRoutes.failed(widget.rideId)),
        onPrimary: () => _advance(const [
          RideDriverAction.complete,
        ], DriverRidePhase.complete),
      ),
      DriverRidePhase.complete => DriverFooter(
        secondaryLabel: l10n.driverBackToJobs,
        primaryLabel: l10n.driverOpenCompletedSample,
        primaryKey: const Key('driver-active-done'),
        onSecondary: () => context.go('/driver/jobs'),
        onPrimary: () => context.push(DriverRoutes.completed(widget.rideId)),
      ),
    };

    final classPhoto = resolveMediaUrl(ride.imageUrl);
    return DriverPageFrame(
      title: title,
      subtitle: rideVehicleClassLabel(l10n, ride.vehicleClassCode),
      trailing: classPhoto == null
          ? null
          : RideVehicleClassPhoto(
              imageUrl: ride.imageUrl,
              code: ride.vehicleClassCode,
              size: 36,
            ),
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
            // r25: no in-app turn-by-turn — just where to go; guidance is
            // handed to Google Maps / Apple Maps / Waze below the map.
            DriverPanel(
              key: const Key('driver-active-destination'),
              child: Row(
                children: [
                  Icon(
                    DealGoIcons.pin,
                    color: _phase == DriverRidePhase.onTrip
                        ? DealGoColors.danger
                        : DealGoColors.primary,
                  ),
                  const SizedBox(width: DealGoSpacing.s12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _phase == DriverRidePhase.onTrip
                              ? l10n.driverFollowRoute
                              : l10n.driverHeadToPickup,
                          style: textTheme.labelMedium?.copyWith(
                            color: DealGoColors.textSecondary,
                          ),
                        ),
                        Text(
                          _phase == DriverRidePhase.onTrip
                              ? ride.dropoff.label
                              : ride.pickup.label,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: textTheme.titleSmall,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: DealGoSpacing.s12),
          ],
          // Waiting at pickup keeps the real map (pickup pin + where the trip goes).
          if (_phase == DriverRidePhase.navigatePickup ||
              _phase == DriverRidePhase.arrived ||
              _phase == DriverRidePhase.onTrip) ...[
            Builder(
              builder: (context) {
                final pickup = MapLatLng(
                  lat: ride.pickup.lat,
                  lng: ride.pickup.lng,
                );
                final dropoff = MapLatLng(
                  lat: ride.dropoff.lat,
                  lng: ride.dropoff.lng,
                );
                final target = _phase == DriverRidePhase.onTrip
                    ? dropoff
                    : pickup;
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    ClipRRect(
                      key: const Key('driver-active-map'),
                      borderRadius: BorderRadius.circular(DealGoRadius.card),
                      child: SizedBox(
                        height: 160,
                        // DEC-PROD-031 rev 3: approach leg first, then trip.
                        child: ServerPhaseRoute(
                          job: TrackedJob.ride,
                          id: ride.id,
                          active: true,
                          approach: _phase == DriverRidePhase.navigatePickup,
                          trip: ride.route,
                          approachSeed: ride.approachRoute,
                          builder: (context, route) =>
                              context.watch<MapPort>().buildMap(
                                // Pins are bottom-anchored (~44 px tall): extra top room so they
                                // never touch the card edge on the small inline map.
                                fitPadding: const EdgeInsets.fromLTRB(
                                  36,
                                  56,
                                  36,
                                  28,
                                ),
                                center: target,
                                markers: [pickup, dropoff],
                                route: route,
                                pulseRoute: true,
                              ),
                        ),
                      ),
                    ),
                    const SizedBox(height: DealGoSpacing.s8),
                    DriverNavigateButtons(
                      lat: target.lat,
                      lng: target.lng,
                      destinationLabel: _phase == DriverRidePhase.onTrip
                          ? AppLocalizations.of(context).driverNavToDropoff
                          : AppLocalizations.of(context).driverNavToPickup,
                    ),
                  ],
                );
              },
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
                                ? l10n.driverDropoffLabel
                                : l10n.driverPickupLabel,
                            style: textTheme.titleMedium,
                          ),
                          Text(
                            _phase == DriverRidePhase.onTrip
                                ? ride.dropoff.label
                                : ride.pickup.label,
                            style: textTheme.bodySmall,
                          ),
                          if (_phase == DriverRidePhase.arrived) ...[
                            const SizedBox(height: DealGoSpacing.s4),
                            Text(
                              l10n.driverDropoffLabel,
                              style: textTheme.labelSmall?.copyWith(
                                color: DealGoColors.textSecondary,
                              ),
                            ),
                            Text(
                              ride.dropoff.label,
                              key: const Key('driver-arrived-dropoff'),
                              style: textTheme.bodySmall,
                            ),
                          ],
                        ],
                      ),
                    ),
                    DriverChip(
                      label: switch (_phase) {
                        DriverRidePhase.navigatePickup =>
                          l10n.driverPhasePickup,
                        DriverRidePhase.arrived => l10n.driverPhaseWaiting,
                        DriverRidePhase.onTrip => l10n.driverPhaseOnTrip,
                        DriverRidePhase.complete => l10n.driverPhaseDone,
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
                      child: Icon(
                        DealGoIcons.user,
                        color: DealGoColors.primary,
                      ),
                    ),
                    const SizedBox(width: DealGoSpacing.s12),
                    Expanded(
                      child: JobCustomerName(
                        jobId: widget.rideId,
                        subtitle: ride.customerRating == null
                            ? null
                            : customerRatingText(l10n, ride.customerRating),
                      ),
                    ),
                    DriverContactActions(resourceId: widget.rideId),
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
                      Text(
                        l10n.rideRef(shortRef(ride.id)),
                        style: textTheme.titleMedium,
                      ),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      formatRideVnd(ride.offeredFareVnd),
                      style: textTheme.titleMedium?.copyWith(
                        color: DealGoColors.primary,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    Text(l10n.driverAgreedFare, style: textTheme.bodySmall),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: DealGoSpacing.s12),
          DriverNote(
            tone: DriverNoteTone.green,
            message: switch (_phase) {
              DriverRidePhase.navigatePickup => l10n.driverRideNavigateNote,
              DriverRidePhase.arrived => l10n.driverActiveWaitingBody,
              DriverRidePhase.onTrip => l10n.driverActiveOnTripBody,
              DriverRidePhase.complete =>
                _discountVnd > 0
                    ? l10n.driverVoucherFunded(formatRideVnd(_discountVnd))
                    : l10n.driverActiveCompleteBody,
            },
          ),
          if (_phase == DriverRidePhase.arrived && canCancel) ...[
            const SizedBox(height: DealGoSpacing.s12),
            DealGoSecondaryButton(
              key: const Key('driver-no-show'),
              label: l10n.driverNoShow,
              tone: DealGoSecondaryTone.danger,
              enabled: !actionBusy,
              onPressed: _noShow,
            ),
          ],
          if (actionError != null) ...[
            const SizedBox(height: DealGoSpacing.s12),
            DriverNote(message: actionError!),
          ],
          if (_phase == DriverRidePhase.complete) ...[
            const SizedBox(height: DealGoSpacing.s12),
            DriverPanel(
              child: Column(
                children: [
                  DriverMoneyRow(
                    label: l10n.driverAgreedFare,
                    value: formatRideVnd(ride.offeredFareVnd),
                    emphasize: true,
                  ),
                  DriverMoneyRow(
                    key: const Key('driver-cash-to-collect'),
                    label: l10n.driverCollect,
                    value: l10n.driverCashToCollect(
                      formatRideVnd(
                        rideCashAfterVoucher(ride.offeredFareVnd, _discountVnd),
                      ),
                    ),
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

/// The phase screen for a ride the server already moved on; null keeps the caller's phase.
DriverRidePhase? driverPhaseForStatus(RideStatus status) => switch (status) {
  RideStatus.assigned ||
  RideStatus.driverEnRoute => DriverRidePhase.navigatePickup,
  RideStatus.driverArrived => DriverRidePhase.arrived,
  RideStatus.inTrip => DriverRidePhase.onTrip,
  RideStatus.completed => DriverRidePhase.complete,
  _ => null,
};

/// A server ride as the driver screens show it; the agreed fare once there is one.
OpenRide openRideFromView(RideView view) => OpenRide(
  id: view.id,
  status: view.status.wire,
  pickup: view.pickup,
  dropoff: view.dropoff,
  offeredFareVnd: view.agreedFareVnd ?? view.offeredFareVnd,
  referenceFareVnd: view.referenceFareVnd,
  expiresAt: view.expiresAt,
  offerCount: view.offers.length,
  vehicleClassCode: view.vehicleClassCode,
  imageUrl: view.imageUrl,
  route: view.route,
  approachRoute: view.approachRoute,
  customerRating: view.customerRating,
);
