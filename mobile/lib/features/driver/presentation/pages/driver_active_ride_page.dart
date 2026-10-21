import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/design_system/components/dealgo_state_view.dart';
import '../../../../core/design_system/tokens/dealgo_tokens.dart';
import '../../../../core/network/request_failure.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../ride/domain/entities/ride_models.dart';
import '../../../ride/domain/entities/ride_money.dart';
import '../../../ride/domain/params/get_ride_params.dart';
import '../../../ride/domain/usecases/get_ride.dart';
import '../../../ride/domain/params/ride_driver_action.dart';
import '../../domain/usecases/advance_driver_ride.dart';
import '../utils/driver_action_runner.dart';
import '../utils/driver_routes.dart';
import '../widgets/driver_contact_actions.dart';
import '../widgets/driver_navigate_buttons.dart';
import '../widgets/driver_widgets.dart';
import '../../../../core/maps/map_lat_lng.dart';
import '../../../../core/maps/map_port.dart';
import '../../../../core/design_system/icons/dealgo_icons.dart';
import '../../../../core/format/short_ref.dart';

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
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
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
      setState(() {
        _loaded = openRideFromView(view);
        _discountVnd = view.discountVnd;
        _enRoute = view.status != RideStatus.assigned && view.status != RideStatus.negotiating;
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
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final textTheme = Theme.of(context).textTheme;
    final ride = _loaded ?? widget.ride;
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
        secondaryLabel: l10n.driverActiveReportIssue,
        primaryLabel: l10n.driverActiveArrivedCta,
        primaryKey: const Key('driver-active-arrived'),
        primaryLoading: actionBusy,
        primaryEnabled: !actionBusy,
        onSecondary: () => context.push(DriverRoutes.failed(widget.rideId)),
        onPrimary: () => _advance([
          if (!_enRoute) RideDriverAction.enRoute,
          RideDriverAction.arrived,
        ], DriverRidePhase.arrived),
      ),
      DriverRidePhase.arrived => DriverFooter(
        secondaryLabel: l10n.driverActiveReportIssue,
        primaryLabel: l10n.driverActiveOpenOtp,
        primaryKey: const Key('driver-active-open-otp'),
        onSecondary: () => context.push(DriverRoutes.failed(widget.rideId)),
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
                        ? DealGoIcons.navigation
                        : DealGoIcons.turnRight,
                    color: Colors.white,
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
                          style: textTheme.titleMedium?.copyWith(
                            color: Colors.white,
                          ),
                        ),
                        Text(
                          _phase == DriverRidePhase.onTrip
                              ? ride.dropoff.label
                              : ride.pickup.label,
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
                        child: context.read<MapPort>().buildMap(
                          center: target,
                          markers: [pickup, dropoff],
                        ),
                      ),
                    ),
                    const SizedBox(height: DealGoSpacing.s8),
                    DriverNavigateButtons(lat: target.lat, lng: target.lng),
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
                      child: Text(
                        l10n.driverPassenger,
                        style: textTheme.titleMedium,
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
                      style: textTheme.titleLarge?.copyWith(
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
              DriverRidePhase.complete => _discountVnd > 0
                  ? l10n.driverVoucherFunded(formatRideVnd(_discountVnd))
                  : l10n.driverActiveCompleteBody,
            },
          ),
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
                      formatRideVnd(rideCashAfterVoucher(ride.offeredFareVnd, _discountVnd)),
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
  RideStatus.assigned || RideStatus.driverEnRoute => DriverRidePhase.navigatePickup,
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
);
