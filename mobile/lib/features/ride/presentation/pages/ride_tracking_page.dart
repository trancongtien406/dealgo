import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/config/api_base_url.dart';
import '../../../../core/design_system/components/dealgo_chip.dart';
import '../../../../core/design_system/components/dealgo_state_view.dart';
import '../../../../core/design_system/components/dealgo_primary_button.dart';
import '../../../../core/design_system/tokens/dealgo_tokens.dart';
import '../../../../core/design_system/components/dealgo_contact_button.dart';
import '../../../../core/maps/map_lat_lng.dart';
import '../../../live_location/domain/driver_location.dart';
import '../../../live_location/presentation/live_driver_map.dart';
import '../../../live_location/presentation/pushed_route_eta.dart';
import '../../../../core/maps/live_route.dart';
import '../../../../core/maps/map_markers.dart';
import '../../../../core/realtime/snapshot_realtime.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../chat/presentation/cubit/chat_cubit.dart';
import '../../../chat/presentation/widgets/chat_unread_badge.dart';
import '../../../chat/presentation/widgets/transaction_chat_sheet.dart';
import '../../../identity/domain/entities/auth_state.dart';
import '../../../identity/presentation/cubit/auth_cubit.dart';
import '../../../voice/domain/entities/voice_models.dart';
import '../../../voice/presentation/widgets/voice_call_actions.dart';
import '../../domain/entities/ride_money.dart';
import '../../domain/entities/ride_models.dart';
import '../../../driver_card/domain/driver_card.dart';
import '../../../driver_card/presentation/driver_card_tile.dart';
import '../../domain/usecases/get_ride.dart';
import '../utils/ride_routes.dart';
import '../utils/ride_vehicle_label.dart';
import '../cubit/ride_tracking_cubit.dart';
import '../widgets/ride_widgets.dart';
import '../../../../core/design_system/icons/dealgo_icons.dart';
import '../../../../core/design_system/components/dealgo_app_header.dart';
import '../../../../core/design_system/components/tracking_layout.dart';
import '../../../chat/presentation/widgets/open_chat_on_arrival.dart';

class RideTrackingPage extends StatelessWidget {
  const RideTrackingPage({required this.rideId, super.key});

  final String rideId;

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) => RideTrackingCubit(
        getRide: context.read<GetRide>(),
        realtime: context.read<SnapshotRealtime>(),
      )..start(rideId: rideId, accessToken: rideAccessToken(context)),
      child: _RideTrackingView(rideId: rideId),
    );
  }
}

class _RideTrackingView extends StatelessWidget {
  const _RideTrackingView({required this.rideId});

  final String rideId;

  void _back(BuildContext context) {
    if (context.canPop()) {
      context.pop();
      return;
    }
    context.go('/customer');
  }

  Future<void> _openChat(BuildContext context, String rideId) {
    final auth = context.read<AuthCubit>().state;
    final userId = auth is AuthSignedIn ? auth.profile.id : null;
    return showTransactionChatSheet(
      context: context,
      kind: ChatThreadKind.ride,
      resourceId: rideId,
      accessToken: rideAccessToken(context),
      currentUserId: userId,
      viewer: ChatViewer.customer,
      onCall: voiceCallsEnabled(context, listen: false)
          ? () => _openVoice(context, rideId)
          : null,
    );
  }

  void _openVoice(BuildContext context, String rideId) {
    startVoiceCall(context, kind: VoiceThreadKind.ride, resourceId: rideId);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: DealGoColors.canvas,
      body: SafeArea(
        child: BlocBuilder<RideTrackingCubit, RideTrackingState>(
          builder: (context, state) {
            final ride = state.ride;
            final loading = state is RideTrackingLoading && ride == null;
            final busy = state.busy;
            if (loading) {
              return Column(
                children: [
                  DealGoAppHeader(
                    title: AppLocalizations.of(context).rideTrackTitle,
                    onBack: () => _back(context),
                  ),
                  const Expanded(
                    child: Center(child: CircularProgressIndicator()),
                  ),
                ],
              );
            }
            if (state is RideTrackingOffline && ride == null) {
              return Column(
                children: [
                  DealGoAppHeader(
                    title: AppLocalizations.of(context).rideTrackTitle,
                    onBack: () => _back(context),
                  ),
                  Expanded(
                    child: DealGoStateView.failure(
                      context,
                      onRetry: () =>
                          context.read<RideTrackingCubit>().refresh(),
                      cause: state.cause,
                    ),
                  ),
                ],
              );
            }
            if (state is RideTrackingOffline) {
              return _TrackingOffline(
                ride: ride,
                busy: busy,
                onBack: () => _back(context),
                onRetry: () => context.read<RideTrackingCubit>().refresh(),
              );
            }
            return OpenChatOnArrival(
              onOpen: () => _openChat(context, rideId),
              child: _TrackingLive(
                ride: ride,
                busy: busy,
                onBack: () => _back(context),
                onRefresh: () => context.read<RideTrackingCubit>().refresh(),
                onOpenChat: () => _openChat(context, rideId),
                onOpenVoice: voiceCallsEnabled(context)
                    ? () => _openVoice(context, rideId)
                    : null,
              ),
            );
          },
        ),
      ),
    );
  }
}

/// Statuses in which the customer sees the driver's live position.
const _rideTrackingStatuses = {
  RideStatus.assigned,
  RideStatus.driverEnRoute,
  RideStatus.driverArrived,
  RideStatus.inTrip,
};

class _TrackingLive extends StatelessWidget {
  const _TrackingLive({
    required this.ride,
    required this.busy,
    required this.onBack,
    required this.onRefresh,
    required this.onOpenChat,
    this.onOpenVoice,
  });

  final RideView? ride;
  final bool busy;
  final VoidCallback onBack;
  final VoidCallback onRefresh;
  final VoidCallback onOpenChat;
  final VoidCallback? onOpenVoice;

  static const _preTrip = {
    RideStatus.negotiating,
    RideStatus.assigned,
    RideStatus.driverEnRoute,
    RideStatus.driverArrived,
  };

  static int _stepIndex(RideStatus status) => switch (status) {
    RideStatus.negotiating => 0,
    RideStatus.assigned || RideStatus.driverEnRoute => 1,
    RideStatus.driverArrived => 2,
    RideStatus.inTrip => 3,
    RideStatus.completed => 4,
    RideStatus.expired || RideStatus.cancelled => 0,
  };

  @override
  Widget build(BuildContext context) {
    final current = ride;
    final l10n = AppLocalizations.of(context);
    if (current == null) {
      return Column(
        children: [
          DealGoAppHeader(title: l10n.rideTrackTitle, onBack: onBack),
          const Expanded(child: Center(child: CircularProgressIndicator())),
        ],
      );
    }
    final agreed = current.agreedFareVnd;
    final openReceipt = agreed == null || current.status != RideStatus.completed
        ? null
        : () => context.push(RideRoutes.receipt(current.id));
    final title = switch (current.status) {
      RideStatus.assigned => l10n.rideTrackAssigned,
      RideStatus.driverEnRoute => l10n.rideTrackAssigned,
      RideStatus.driverArrived => l10n.rideTrackArrived,
      RideStatus.inTrip => l10n.rideTrackInTrip,
      RideStatus.completed => l10n.rideTrackCompleted,
      RideStatus.negotiating => l10n.rideTrackNegotiating,
      RideStatus.expired => l10n.rideTrackExpired,
      RideStatus.cancelled => l10n.rideTrackCancelled,
    };
    // DEC-PROD-017: issued by the backend, only on the customer's own ride.
    final pickupCode = current.pickupCode;
    final hasDriver = current.assignedDriverId != null;
    final inTrip = current.status == RideStatus.inTrip;
    // ETA: only the server route duration (pickup→dropoff) is real data; the
    // driver→pickup ETA is not provided by the API (OPEN-RIDE-ETA).
    final durationSec = current.route.durationSec;
    // DEC-PROD-031 rev 3 (DRAFT): driver→pickup ETA = server approach leg.
    final approachSec = current.approachRoute?.durationSec;
    final eta = inTrip && durationSec != null && durationSec > 0
        ? l10n.trackEtaMinutes((durationSec / 60).ceil())
        : !inTrip && approachSec != null && approachSec > 0
        ? l10n.trackEtaMinutes((approachSec / 60).ceil())
        : null;
    final pickup = MapLatLng(lat: current.pickup.lat, lng: current.pickup.lng);
    final dropoff = MapLatLng(
      lat: current.dropoff.lat,
      lng: current.dropoff.lng,
    );
    final canCancel = _preTrip.contains(current.status);
    return TrackingScaffold(
      onBack: onBack,
      // Status and route chips wrap onto a second line on narrow phones
      // instead of squeezing the status label to nothing.
      topCenter: Wrap(
        spacing: DealGoSpacing.s8,
        runSpacing: DealGoSpacing.s4,
        children: [
          DealGoChip(
            key: const Key('ride-tracking-status-chip'),
            label: title,
            tone: DealGoChipTone.neutral,
            leading: resolveMediaUrl(current.imageUrl) == null
                ? Icon(rideVehicleClassIcon(current.vehicleClassCode), size: 14)
                : RideVehicleClassPhoto(
                    imageUrl: current.imageUrl,
                    code: current.vehicleClassCode,
                    size: 18,
                  ),
          ),
          DealGoChip(
            key: const Key('ride-tracking-route-chip'),
            label: current.route.hasRoadPolyline
                ? l10n.mapRouteRoadFollowed
                : l10n.mapRouteStraightFallback,
            tone: current.route.hasRoadPolyline
                ? DealGoChipTone.brand
                : DealGoChipTone.neutral,
          ),
        ],
      ),
      topTrailing: TrackingRoundButton(
        key: const Key('ride-tracking-retry'),
        tooltip: l10n.actionReload,
        icon: DealGoIcons.refresh,
        onPressed: busy ? null : onRefresh,
      ),
      map: LiveDriverMap(
        job: TrackedJob.ride,
        sheetFraction: 0.48,
        id: current.id,
        tracking: hasDriver && _rideTrackingStatuses.contains(current.status),
        center: inTrip ? dropoff : pickup,
        markers: inTrip ? [dropoff] : [pickup, dropoff],
        route: current.route.polylineOr(const []),
        roadFollowed: current.route.hasRoadPolyline,
        phase: inTrip ? LiveRoutePhase.toDropoff : LiveRoutePhase.toPickup,
        liveRouteTo: inTrip ? dropoff : pickup,
        serverRoute: inTrip ? null : current.approachRoute,
        vehicle: mapVehicleForClass(current.vehicleClassCode),
        firstMarkerIsPickup: !inTrip,
      ),
      sheet: [
        PushedRouteEta(
          aggregateType: 'Ride',
          id: current.id,
          phase: !hasDriver
              ? null
              : inTrip
              ? 'TRIP'
              : _rideTrackingStatuses.contains(current.status)
              ? 'APPROACH'
              : null,
          fallbackSec: null,
          // Cached server leg; the ETA counts down along it on each GPS ping.
          seedRoute: inTrip ? current.route : current.approachRoute,
          builder: (context, pushedSec) => TrackingHeadline(
            title: title,
            // Live leg ETA wins; otherwise the REST snapshot ETA computed above.
            eta: pushedSec != null && pushedSec > 0
                ? l10n.trackEtaMinutes((pushedSec / 60).ceil())
                : eta,
            subtitle: rideVehicleClassLabel(l10n, current.vehicleClassCode),
          ),
        ),
        const SizedBox(height: DealGoSpacing.s16),
        TrackingTimeline(
          key: const Key('ride-tracking-timeline'),
          failed:
              current.status == RideStatus.cancelled ||
              current.status == RideStatus.expired,
          current: _stepIndex(current.status),
          steps: [
            TrackingStep(DealGoIcons.search, l10n.trackStepFinding),
            TrackingStep(
              rideVehicleClassIcon(current.vehicleClassCode),
              l10n.trackStepComing,
            ),
            TrackingStep(DealGoIcons.pin, l10n.trackStepArrived),
            TrackingStep(DealGoIcons.map, l10n.trackStepOnTrip),
            TrackingStep(DealGoIcons.success, l10n.trackStepDone),
          ],
        ),
        if (current.status == RideStatus.negotiating)
          TrackingSection(
            key: const Key('ride-tracking-awaiting-offers'),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  l10n.rideMatchingWaiting,
                  style: Theme.of(context).textTheme.titleSmall,
                ),
                const SizedBox(height: DealGoSpacing.s8),
                DealGoPrimaryButton(
                  key: const Key('ride-tracking-open-matching'),
                  label: l10n.rideMatchingReceiving,
                  enabled: !busy,
                  onPressed: () => context.go(RideRoutes.matching(current.id)),
                ),
              ],
            ),
          )
        else
          TrackingSection(
            child: DriverCardTile(
              job: DriverCardJob.ride,
              jobId: current.id,
              accessToken: rideAccessToken(context) ?? '',
              assigned: hasDriver,
              trailing: hasDriver
                  ? DealGoContactActions(
                      children: [
                        DealGoContactButton(
                          key: const Key('ride-open-chat'),
                          tooltip: l10n.chatContact,
                          onPressed: busy ? null : onOpenChat,
                          icon: ChatUnreadBadge(
                            aggregateType: 'Ride',
                            aggregateId: current.id,
                            child: const Icon(DealGoIcons.chat),
                          ),
                        ),
                        if (onOpenVoice != null)
                          DealGoContactButton(
                            key: const Key('ride-open-voice'),
                            tooltip: l10n.voiceCall,
                            onPressed: busy ? null : onOpenVoice,
                            filled: true,
                            icon: const Icon(DealGoIcons.phone),
                          ),
                      ],
                    )
                  : null,
            ),
          ),
        if (pickupCode != null)
          TrackingSection(
            child: TrackingCodeRow(
              key: const Key('ride-open-pickup-code'),
              icon: DealGoIcons.shield,
              label: l10n.ridePickupCodeTitle,
              code: pickupCode.split('').join(' '),
              codeKey: const Key('ride-pickup-code'),
              onTap: () => context.push(RideRoutes.pickupCode(current.id)),
            ),
          ),
        TrackingSection(
          child: RideStopList(
            pickup: current.pickup.label,
            dropoff: current.dropoff.label,
          ),
        ),
        TrackingSection(
          child: Column(
            children: [
              RideMoneyLine(
                label: l10n.rideAgreedFare,
                amount: agreed == null ? '—' : formatRideVnd(agreed),
                emphasize: agreed != null && current.discountVnd == 0,
              ),
              if (agreed != null && current.discountVnd > 0) ...[
                RideMoneyLine(
                  label: l10n.rideVoucherLine(current.voucherCode ?? ''),
                  amount: formatRideVnd(-current.discountVnd),
                ),
                RideMoneyLine(
                  key: const Key('ride-cash-due'),
                  label: l10n.rideCashDueLabel,
                  amount: formatRideVnd(
                    rideCashAfterVoucher(agreed, current.discountVnd),
                  ),
                  emphasize: true,
                ),
              ],
            ],
          ),
        ),
        TrackingSection(
          child: Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  key: const Key('ride-open-safety'),
                  onPressed: () => context.push(RideRoutes.safety(current.id)),
                  icon: const Icon(DealGoIcons.shield, size: 16),
                  label: Text(l10n.rideShareTrip),
                ),
              ),
              if (canCancel) ...[
                const SizedBox(width: DealGoSpacing.s8),
                Expanded(
                  child: OutlinedButton.icon(
                    key: const Key('ride-tracking-open-cancel'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: DealGoColors.danger,
                    ),
                    onPressed: busy
                        ? null
                        : () => context.push(RideRoutes.cancel(current.id)),
                    icon: const Icon(DealGoIcons.close, size: 16),
                    label: Text(l10n.rideCancelTitle),
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
      footer: openReceipt == null
          ? null
          : DealGoPrimaryButton(
              key: const Key('ride-open-receipt'),
              label: l10n.rideViewReceipt,
              enabled: !busy,
              onPressed: openReceipt,
            ),
    );
  }
}

class _TrackingOffline extends StatelessWidget {
  const _TrackingOffline({
    required this.ride,
    required this.busy,
    required this.onBack,
    required this.onRetry,
  });

  final RideView? ride;
  final bool busy;
  final VoidCallback onBack;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final current = ride;
    final agreed = current?.agreedFareVnd;
    final l10n = AppLocalizations.of(context);
    return Column(
      children: [
        DealGoAppHeader(title: l10n.rideTrackTitle, onBack: onBack),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(
              DealGoDimensions.pageGutter,
              DealGoSpacing.s8,
              DealGoDimensions.pageGutter,
              DealGoSpacing.s16,
            ),
            children: [
              RideStateHero(
                icon: DealGoIcons.offline,
                iconColor: DealGoColors.warning,
                background: DealGoColors.amberSurface,
                title: l10n.rideOfflineTitle,
                message: l10n.rideOfflineBody,
              ),
              const SizedBox(height: DealGoSpacing.s16),
              if (current != null)
                RidePanel(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      RideSectionTitle(l10n.rideTripSummary),
                      const SizedBox(height: DealGoSpacing.s8),
                      RideMoneyLine(
                        label: l10n.ridePickup,
                        amount: current.pickup.label,
                      ),
                      RideMoneyLine(
                        label: l10n.rideDropoff,
                        amount: current.dropoff.label,
                      ),
                      RideMoneyLine(
                        label: l10n.rideVehicleLabel,
                        amount: rideVehicleClassLabel(
                          l10n,
                          current.vehicleClassCode,
                        ),
                      ),
                      if (agreed != null)
                        RideMoneyLine(
                          label: l10n.rideAgreedFare,
                          amount: formatRideVnd(agreed),
                        ),
                      if (agreed != null && current.discountVnd > 0)
                        RideMoneyLine(
                          label: l10n.rideCashDueLabel,
                          amount: formatRideVnd(
                            rideCashAfterVoucher(agreed, current.discountVnd),
                          ),
                        ),
                    ],
                  ),
                ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.all(DealGoDimensions.pageGutter),
          child: DealGoPrimaryButton(
            key: const Key('ride-tracking-retry'),
            label: AppLocalizations.of(context).actionRetry,
            isLoading: busy,
            onPressed: onRetry,
          ),
        ),
      ],
    );
  }
}
