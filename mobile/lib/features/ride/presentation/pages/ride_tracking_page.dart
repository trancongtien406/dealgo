import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/design_system/components/dealgo_chip.dart';
import '../../../../core/design_system/components/dealgo_state_view.dart';
import '../../../../core/design_system/components/dealgo_primary_button.dart';
import '../../../../core/design_system/components/dealgo_secondary_button.dart';
import '../../../../core/design_system/tokens/dealgo_tokens.dart';
import '../../../../core/maps/map_lat_lng.dart';
import '../../../live_location/domain/driver_location.dart';
import '../../../live_location/presentation/live_driver_map.dart';
import '../../../../core/realtime/snapshot_realtime.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../chat/presentation/cubit/chat_cubit.dart';
import '../../../chat/presentation/widgets/transaction_chat_sheet.dart';
import '../../../identity/domain/entities/auth_state.dart';
import '../../../identity/presentation/cubit/auth_cubit.dart';
import '../../../voice/domain/entities/voice_models.dart';
import '../../../voice/presentation/widgets/voice_call_sheet.dart';
import '../../domain/entities/ride_money.dart';
import '../../domain/entities/ride_models.dart';
import '../../../driver_card/domain/driver_card.dart';
import '../../../driver_card/presentation/driver_card_tile.dart';
import '../../domain/usecases/get_ride.dart';
import '../utils/ride_routes.dart';
import '../cubit/ride_tracking_cubit.dart';
import '../widgets/ride_widgets.dart';
import '../../../../core/design_system/icons/dealgo_icons.dart';
import '../../../../core/design_system/components/dealgo_app_header.dart';

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
    );
  }

  Future<void> _openVoice(BuildContext context, String rideId) {
    return showVoiceCallSheet(
      context: context,
      kind: VoiceThreadKind.ride,
      resourceId: rideId,
      accessToken: rideAccessToken(context),
    );
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
                      onRetry: () => context.read<RideTrackingCubit>().refresh(),
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
            return _TrackingLive(
              ride: ride,
              busy: busy,
              onBack: () => _back(context),
              onRefresh: () => context.read<RideTrackingCubit>().refresh(),
              onOpenChat: () => _openChat(context, rideId),
              onOpenVoice: () => _openVoice(context, rideId),
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
    required this.onOpenVoice,
  });

  final RideView? ride;
  final bool busy;
  final VoidCallback onBack;
  final VoidCallback onRefresh;
  final VoidCallback onOpenChat;
  final VoidCallback onOpenVoice;

  @override
  Widget build(BuildContext context) {
    final current = ride;
    final agreed = current?.agreedFareVnd;
    final openReceipt = current == null || agreed == null
        ? null
        : () => context.push(RideRoutes.receipt(current.id));
    final l10n = AppLocalizations.of(context);
    final title = current == null
        ? l10n.rideTrackTitle
        : switch (current.status) {
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
    final pickupCode = current?.pickupCode;
    return Column(
      children: [
        DealGoAppHeader(
          title: title,
          onBack: onBack,
          trailing: IconButton(
            key: const Key('ride-tracking-retry'),
            tooltip: l10n.actionReload,
            onPressed: busy ? null : onRefresh,
            icon: const Icon(DealGoIcons.refresh, color: DealGoColors.text),
          ),
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
              if (current != null) ...[
                ClipRRect(
                  borderRadius: BorderRadius.circular(DealGoRadius.card),
                  child: SizedBox(
                    height: 200,
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        LiveDriverMap(
                          job: TrackedJob.ride,
                          id: current.id,
                          tracking:
                              current.assignedDriverId != null &&
                              _rideTrackingStatuses.contains(current.status),
                          center: MapLatLng(
                            lat: current.pickup.lat,
                            lng: current.pickup.lng,
                          ),
                          markers: [
                            MapLatLng(
                              lat: current.pickup.lat,
                              lng: current.pickup.lng,
                            ),
                            MapLatLng(
                              lat: current.dropoff.lat,
                              lng: current.dropoff.lng,
                            ),
                          ],
                        ),
                        // Live driver position (DEC-PROD-031); no ETA is
                        // invented from it.
                        Positioned(
                          top: DealGoSpacing.s12,
                          left: DealGoSpacing.s12,
                          child: DealGoChip(
                            key: const Key('ride-tracking-status-chip'),
                            label: title,
                            tone: DealGoChipTone.neutral,
                            leading: const Icon(DealGoIcons.car, size: 14),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: DealGoSpacing.s12),
                RidePanel(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      RideSectionTitle(l10n.rideDriverAssignedTitle),
                      const SizedBox(height: DealGoSpacing.s12),
                      DriverCardTile(
                        job: DriverCardJob.ride,
                        jobId: current.id,
                        accessToken: rideAccessToken(context) ?? '',
                        assigned: current.assignedDriverId != null,
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton.filled(
                              key: const Key('ride-open-voice'),
                              tooltip: AppLocalizations.of(context).voiceCall,
                              onPressed: busy ? null : onOpenVoice,
                              style: IconButton.styleFrom(
                                backgroundColor: DealGoColors.primary,
                              ),
                              icon: const Icon(
                                DealGoIcons.phone,
                                color: DealGoColors.card,
                              ),
                            ),
                            const SizedBox(width: DealGoSpacing.s8),
                            IconButton.outlined(
                              key: const Key('ride-open-chat'),
                              onPressed: busy ? null : onOpenChat,
                              style: IconButton.styleFrom(
                                foregroundColor: DealGoColors.primary,
                                side: const BorderSide(
                                  color: DealGoColors.primary,
                                ),
                              ),
                              icon: const Icon(DealGoIcons.chat),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: DealGoSpacing.s12),
                RidePanel(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      RideSectionTitle(l10n.rideTripInfo),
                      const SizedBox(height: DealGoSpacing.s12),
                      RideStopList(
                        pickup: current.pickup.label,
                        dropoff: current.dropoff.label,
                      ),
                      const SizedBox(height: DealGoSpacing.s12),
                      RideMoneyLine(
                        label: l10n.rideAgreedFare,
                        amount: agreed == null ? '—' : formatRideVnd(agreed),
                        emphasize: agreed != null && current.discountVnd == 0,
                      ),
                      if (agreed != null && current.discountVnd > 0) ...[
                        RideMoneyLine(
                          label: l10n.rideVoucherLine(
                            current.voucherCode ?? '',
                          ),
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
                if (pickupCode != null) ...[
                  const SizedBox(height: DealGoSpacing.s12),
                  RidePanel(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        RideSectionTitle(l10n.ridePickupCodeTitle),
                        Text(
                          l10n.ridePickupCodeHint,
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                        const SizedBox(height: DealGoSpacing.s12),
                        InkWell(
                          key: const Key('ride-open-pickup-code'),
                          onTap: () =>
                              context.push(RideRoutes.pickupCode(current.id)),
                          child: Row(
                            children: [
                              Expanded(
                                child: Text(
                                  pickupCode.split('').join(' '),
                                  key: const Key('ride-pickup-code'),
                                  style: Theme.of(context)
                                      .textTheme
                                      .headlineMedium
                                      ?.copyWith(fontWeight: FontWeight.w800),
                                ),
                              ),
                              const DecoratedBox(
                                decoration: BoxDecoration(
                                  color: DealGoColors.greenSurface,
                                  shape: BoxShape.circle,
                                ),
                                child: SizedBox(
                                  width: 36,
                                  height: 36,
                                  child: Icon(
                                    DealGoIcons.check,
                                    color: DealGoColors.brandGreen,
                                    size: 20,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        Align(
                          alignment: Alignment.centerLeft,
                          child: TextButton(
                            onPressed: () =>
                                context.push(RideRoutes.pickupCode(current.id)),
                            child: Text(
                              AppLocalizations.of(context).ridePickupCodeTitle,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
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
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              RideDualActions(
                secondaryLabel: AppLocalizations.of(context).rideShareTrip,
                primaryLabel: AppLocalizations.of(context).chatContact,
                primaryKey: const Key('ride-open-chat-cta'),
                enabled: !busy,
                onSecondary: current == null
                    ? () {}
                    : () => context.push(RideRoutes.safety(current.id)),
                onPrimary: onOpenChat,
              ),
              if (current != null) ...[
                const SizedBox(height: DealGoSpacing.s8),
                DealGoSecondaryButton(
                  label: AppLocalizations.of(context).rideSafetyTitle,
                  onPressed: () => context.push(RideRoutes.safety(current.id)),
                ),
              ],
              if (current != null &&
                  current.status == RideStatus.negotiating) ...[
                const SizedBox(height: DealGoSpacing.s8),
                TextButton(
                  key: const Key('ride-tracking-open-cancel'),
                  onPressed: busy
                      ? null
                      : () => context.push(RideRoutes.cancel(current.id)),
                  child: Text(AppLocalizations.of(context).rideCancelTitle),
                ),
              ],
              if (openReceipt != null) ...[
                const SizedBox(height: DealGoSpacing.s8),
                DealGoPrimaryButton(
                  key: const Key('ride-open-receipt'),
                  label: AppLocalizations.of(context).rideViewReceipt,
                  enabled: !busy,
                  onPressed: openReceipt,
                ),
              ],
            ],
          ),
        ),
      ],
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
                        amount: l10n.rideVehicleBikeTitle,
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
              const SizedBox(height: DealGoSpacing.s12),
              RideNote(message: l10n.rideOfflineNote),
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
