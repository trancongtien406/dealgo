import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../driver_card/domain/driver_card.dart';
import '../../../driver_card/presentation/driver_card_tile.dart';

import '../../../../core/design_system/components/dealgo_banner.dart';
import '../../../../core/design_system/components/dealgo_chip.dart';
import '../../../../core/design_system/components/dealgo_primary_button.dart';
import '../../../../core/design_system/tokens/dealgo_tokens.dart';
import '../../../../core/design_system/components/dealgo_contact_button.dart';
import '../../../../core/maps/map_lat_lng.dart';
import '../../../live_location/presentation/pushed_route_eta.dart';
import '../../../live_location/domain/driver_location.dart';
import '../../../live_location/presentation/live_driver_map.dart';
import '../../../../core/realtime/snapshot_realtime.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../chat/presentation/cubit/chat_cubit.dart';
import '../../../chat/presentation/widgets/chat_unread_badge.dart';
import '../../../chat/presentation/widgets/transaction_chat_sheet.dart';
import '../../../identity/domain/entities/auth_state.dart';
import '../../../identity/presentation/cubit/auth_cubit.dart';
import '../../../voice/domain/entities/voice_models.dart';
import '../../../voice/presentation/widgets/voice_call_actions.dart';
import '../../domain/entities/food_models.dart';
import '../../domain/entities/food_money.dart';
import '../../domain/usecases/get_food_order.dart';
import '../utils/food_routes.dart';
import '../cubit/food_tracking_cubit.dart';
import '../widgets/food_order_change_card.dart';
import '../widgets/food_reject_reason.dart';
import '../widgets/food_reorder_button.dart';
import '../widgets/food_widgets.dart';
import '../../../../core/design_system/icons/dealgo_icons.dart';
import '../../../../core/format/short_ref.dart';
import '../../../../core/design_system/components/dealgo_app_header.dart';
import '../../../../core/design_system/components/tracking_layout.dart';
import '../../../../core/design_system/components/dealgo_state_view.dart';
import '../../../../core/maps/route_geometry.dart';
import '../../../../core/maps/live_route.dart';
import '../../../chat/presentation/widgets/open_chat_on_arrival.dart';

class FoodTrackingPage extends StatelessWidget {
  const FoodTrackingPage({required this.orderId, super.key});

  final String orderId;

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) => FoodTrackingCubit(
        getFoodOrder: context.read<GetFoodOrder>(),
        realtime: context.read<SnapshotRealtime>(),
      )..start(orderId: orderId, accessToken: currentAccessToken(context)),
      child: _FoodTrackingView(orderId: orderId),
    );
  }
}

class _FoodTrackingView extends StatelessWidget {
  const _FoodTrackingView({required this.orderId});

  final String orderId;

  void _back(BuildContext context) {
    if (context.canPop()) {
      context.pop();
      return;
    }
    context.go('/customer/shop');
  }

  Future<void> _openChat(BuildContext context, String orderId) {
    final auth = context.read<AuthCubit>().state;
    final userId = auth is AuthSignedIn ? auth.profile.id : null;
    return showTransactionChatSheet(
      context: context,
      kind: ChatThreadKind.foodOrder,
      resourceId: orderId,
      accessToken: currentAccessToken(context),
      currentUserId: userId,
      viewer: ChatViewer.customer,
      onCall: voiceCallsEnabled(context, listen: false)
          ? () => _openVoice(context, orderId)
          : null,
    );
  }

  void _openVoice(BuildContext context, String orderId) {
    startVoiceCall(
      context,
      kind: VoiceThreadKind.foodOrder,
      resourceId: orderId,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: DealGoColors.canvas,
      body: SafeArea(
        child: BlocBuilder<FoodTrackingCubit, FoodTrackingState>(
          builder: (context, state) {
            final order = state.order;
            final loading = state is FoodTrackingLoading && order == null;
            final busy = state.busy;
            if (loading) {
              return Column(
                children: [
                  DealGoAppHeader(
                    title: AppLocalizations.of(context).foodTrackingTitle,
                    onBack: () => _back(context),
                  ),
                  const Expanded(
                    child: Center(child: CircularProgressIndicator()),
                  ),
                ],
              );
            }
            if (state is FoodTrackingOffline && order == null) {
              return Column(
                children: [
                  DealGoAppHeader(
                    title: AppLocalizations.of(context).foodTrackingTitle,
                    onBack: () => _back(context),
                  ),
                  Expanded(
                    child: DealGoStateView.failure(
                      context,
                      onRetry: () =>
                          context.read<FoodTrackingCubit>().refresh(),
                      cause: state.cause,
                    ),
                  ),
                ],
              );
            }
            if (state is FoodTrackingOffline) {
              return _FoodReconnect(
                order: order,
                busy: busy,
                onBack: () => _back(context),
                onRetry: () => context.read<FoodTrackingCubit>().refresh(),
              );
            }
            return OpenChatOnArrival(
              onOpen: () => _openChat(context, orderId),
              child: _FoodLive(
                order: order,
                busy: busy,
                onBack: () => _back(context),
                onRefresh: () => context.read<FoodTrackingCubit>().refresh(),
                onCancelStub: () => context.push(FoodRoutes.cancel(orderId)),
                onOpenChat: () => _openChat(context, orderId),
                onOpenVoice: voiceCallsEnabled(context)
                    ? () => _openVoice(context, orderId)
                    : null,
              ),
            );
          },
        ),
      ),
    );
  }
}

class _FoodLive extends StatelessWidget {
  const _FoodLive({
    required this.order,
    required this.busy,
    required this.onBack,
    required this.onRefresh,
    required this.onCancelStub,
    required this.onOpenChat,
    this.onOpenVoice,
  });

  final FoodOrderDetail? order;
  final bool busy;
  final VoidCallback onBack;
  final VoidCallback onRefresh;
  final VoidCallback onCancelStub;
  final VoidCallback onOpenChat;
  final VoidCallback? onOpenVoice;

  static int _stepIndex(String status) => switch (status) {
    'PLACED' => 0,
    'PREPARING' => 1,
    'READY' || 'ASSIGNED' => 2,
    'PICKED_UP' => 3,
    'DELIVERED' => 4,
    _ => 0,
  };

  @override
  Widget build(BuildContext context) {
    final current = order;
    final l10n = AppLocalizations.of(context);
    final textTheme = Theme.of(context).textTheme;
    if (current == null) {
      return Column(
        children: [
          DealGoAppHeader(title: l10n.foodTrackingTitle, onBack: onBack),
          const Expanded(child: Center(child: CircularProgressIndicator())),
        ],
      );
    }
    final title = foodTrackingTitle(
      l10n,
      current.stage,
      status: current.status,
    );
    final failed =
        current.stage == FoodTrackingStage.cancelled ||
        current.stage == FoodTrackingStage.failed;
    final readyAt = current.estimatedReadyAt;
    final durationSec = current.route?.durationSec;
    final eta = current.stage == FoodTrackingStage.preparing && readyAt != null
        ? MaterialLocalizations.of(context).formatTimeOfDay(
            TimeOfDay.fromDateTime(readyAt.toLocal()),
            alwaysUse24HourFormat: true,
          )
        : current.status == 'PICKED_UP' &&
              durationSec != null &&
              durationSec > 0
        ? l10n.trackEtaMinutes((durationSec / 60).ceil())
        // DEC-PROD-031 rev 3 (DRAFT): driver→store ETA = server approach leg.
        : current.status == 'ASSIGNED' &&
              (current.approachRoute?.durationSec ?? 0) > 0
        ? l10n.trackEtaMinutes(
            (current.approachRoute!.durationSec! / 60).ceil(),
          )
        : null;
    final hasDriver = current.assignedDriverId != null;
    final contact = current.stage == FoodTrackingStage.cancelled
        ? null
        : DealGoContactActions(
            children: [
              DealGoContactButton(
                key: const Key('food-open-chat'),
                tooltip: l10n.chatContact,
                onPressed: busy ? null : onOpenChat,
                icon: ChatUnreadBadge(
                  aggregateType: 'FoodOrder',
                  aggregateId: current.id,
                  child: const Icon(DealGoIcons.chat),
                ),
              ),
              if (onOpenVoice != null)
                DealGoContactButton(
                  key: const Key('food-open-voice'),
                  tooltip: l10n.voiceCall,
                  onPressed: busy ? null : onOpenVoice,
                  filled: true,
                  color: DealGoColors.brandGreen,
                  icon: const Icon(DealGoIcons.phone),
                ),
            ],
          );
    final lines = current.lines;
    const shownLines = 3;
    return TrackingScaffold(
      onBack: onBack,
      topTrailing: TrackingRoundButton(
        key: const Key('food-tracking-retry'),
        tooltip: l10n.actionReload,
        icon: DealGoIcons.refresh,
        onPressed: busy ? null : onRefresh,
      ),
      map: _FoodOnTheWayMap(order: current),
      sheet: [
        PushedRouteEta(
          aggregateType: 'FoodOrder',
          id: current.id,
          phase: current.status == 'PICKED_UP'
              ? 'TRIP'
              : current.status == 'ASSIGNED'
              ? 'APPROACH'
              : null,
          fallbackSec: null,
          // Cached server leg; the ETA counts down along it on each GPS ping.
          seedRoute: current.status == 'PICKED_UP'
              ? current.route
              : current.approachRoute,
          builder: (context, pushedSec) => TrackingHeadline(
            title: title,
            // Live leg ETA wins; otherwise the REST snapshot ETA computed above.
            eta: pushedSec != null && pushedSec > 0
                ? l10n.trackEtaMinutes((pushedSec / 60).ceil())
                : eta,
            subtitle: '${l10n.foodInvoiceOrderId} ${shortRef(current.id)}',
          ),
        ),
        if (current.stage == FoodTrackingStage.preparing && readyAt != null)
          Text(
            l10n.foodTrackingReadyBy(eta ?? ''),
            key: const Key('food-tracking-ready-by'),
            style: textTheme.bodySmall?.copyWith(
              color: DealGoColors.textSecondary,
            ),
          ),
        const SizedBox(height: DealGoSpacing.s16),
        TrackingTimeline(
          key: const Key('food-tracking-timeline'),
          failed: failed,
          current: _stepIndex(current.status),
          steps: [
            TrackingStep(DealGoIcons.receipt, l10n.trackStepPlaced),
            TrackingStep(DealGoIcons.store, l10n.trackStepPreparing),
            current.status == 'ASSIGNED'
                ? TrackingStep(
                    DealGoIcons.motorbike,
                    l10n.trackStepDriverToStore,
                  )
                : TrackingStep(DealGoIcons.package, l10n.trackStepReady),
            TrackingStep(DealGoIcons.motorbike, l10n.trackStepDelivering),
            TrackingStep(DealGoIcons.success, l10n.trackStepDelivered),
          ],
        ),
        if (current.cancelReason case final reason?)
          TrackingSection(
            child: DealGoBanner(
              key: const Key('food-tracking-reject-reason'),
              tone: DealGoBannerTone.warning,
              title: l10n.foodRejectedTitle,
              message: foodCancelReasonText(l10n, reason),
            ),
          ),
        if (current.pendingChange case final change? when change.pending)
          TrackingSection(
            child: FoodOrderChangeCard(
              orderId: current.id,
              change: change,
              onAnswered: onRefresh,
              accessToken: currentAccessToken(context),
            ),
          ),
        if (current.deliveryCode case final code?)
          if (current.stage == FoodTrackingStage.onTheWay)
            TrackingSection(
              key: const Key('food-delivery-code-panel'),
              child: TrackingCodeRow(
                icon: DealGoIcons.shield,
                label: l10n.foodDeliveryCodeTitle,
                code: code,
                codeKey: const Key('food-delivery-code'),
              ),
            ),
        if (hasDriver)
          TrackingSection(
            child: DriverCardTile(
              job: DriverCardJob.foodOrder,
              jobId: current.id,
              accessToken: currentAccessToken(context) ?? '',
              assigned: true,
              trailing: contact,
            ),
          ),
        TrackingSection(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const CircleAvatar(
                    radius: 18,
                    backgroundColor: DealGoColors.subtlePurple,
                    child: Icon(
                      DealGoIcons.store,
                      size: 18,
                      color: DealGoColors.primary,
                    ),
                  ),
                  const SizedBox(width: DealGoSpacing.s12),
                  Expanded(
                    child: Text(
                      current.storeName ?? '—',
                      key: const Key('food-tracking-store'),
                      style: textTheme.titleMedium,
                    ),
                  ),
                  if (!hasDriver) ?contact,
                ],
              ),
              const SizedBox(height: DealGoSpacing.s8),
              for (final line in lines.take(shownLines))
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 2),
                  child: Row(
                    children: [
                      Text(
                        '${line.quantity}×',
                        style: textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                          color: DealGoColors.primary,
                        ),
                      ),
                      const SizedBox(width: DealGoSpacing.s8),
                      Expanded(
                        child: Text(
                          line.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      Text(
                        formatVnd(line.unitPriceVnd * line.quantity),
                        style: textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
              if (lines.length > shownLines)
                Text(
                  l10n.trackItemsMore(lines.length - shownLines),
                  style: textTheme.bodySmall?.copyWith(
                    color: DealGoColors.textSecondary,
                  ),
                ),
            ],
          ),
        ),
        TrackingSection(
          child: Row(
            children: [
              const Icon(DealGoIcons.pin, size: 18, color: DealGoColors.danger),
              const SizedBox(width: DealGoSpacing.s8),
              Expanded(
                child: Text(
                  current.dropoff.label,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: textTheme.bodyMedium,
                ),
              ),
            ],
          ),
        ),
        TrackingSection(
          child: Column(
            children: [
              if (current.discountVnd > 0)
                FoodMoneyRow(
                  label: l10n.foodInvoiceDiscount,
                  amount: formatVnd(-current.discountVnd),
                ),
              FoodMoneyRow(
                label: failed ? l10n.foodCustomerPays : l10n.foodTrackingCodDue,
                amount: formatVnd(current.totalVnd),
                emphasize: true,
              ),
            ],
          ),
        ),
        TrackingSection(
          child: Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  key: const Key('food-open-invoice'),
                  onPressed: busy
                      ? null
                      : () => context.push(FoodRoutes.invoice(current.id)),
                  icon: const Icon(DealGoIcons.receipt, size: 16),
                  label: Text(l10n.foodInvoiceTitle),
                ),
              ),
              if (current.stage == FoodTrackingStage.preparing) ...[
                const SizedBox(width: DealGoSpacing.s8),
                Expanded(
                  child: OutlinedButton.icon(
                    key: const Key('food-open-cancel-reasons'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: DealGoColors.danger,
                    ),
                    onPressed: busy ? null : onCancelStub,
                    icon: const Icon(DealGoIcons.close, size: 16),
                    label: Text(l10n.foodCancelTitle),
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
      footer:
          current.stage == FoodTrackingStage.delivered ||
              current.stage == FoodTrackingStage.cancelled
          ? Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (current.stage == FoodTrackingStage.cancelled) ...[
                  DealGoPrimaryButton(
                    key: const Key('food-cancelled-browse'),
                    label: l10n.foodCancelledBrowse,
                    onPressed: () => context.go('/customer/shop'),
                  ),
                  const SizedBox(height: DealGoSpacing.s8),
                ],
                // Reorder only once the order really reached the customer.
                if (current.stage == FoodTrackingStage.delivered)
                  FoodReorderButton(order: current),
              ],
            )
          : null,
    );
  }
}

class _FoodReconnect extends StatelessWidget {
  const _FoodReconnect({
    required this.order,
    required this.busy,
    required this.onBack,
    required this.onRetry,
  });

  final FoodOrderDetail? order;
  final bool busy;
  final VoidCallback onBack;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final current = order;
    final textTheme = Theme.of(context).textTheme;
    return Column(
      children: [
        DealGoAppHeader(
          title: AppLocalizations.of(context).foodTrackOrder,
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
              const Center(
                child: FoodStateIcon(
                  icon: DealGoIcons.offline,
                  background: DealGoColors.amberSurface,
                  foreground: DealGoColors.warning,
                ),
              ),
              const SizedBox(height: DealGoSpacing.s16),
              Text(
                AppLocalizations.of(context).foodReconnecting,
                textAlign: TextAlign.center,
                style: textTheme.titleMedium,
              ),
              const SizedBox(height: DealGoSpacing.s8),
              Text(
                AppLocalizations.of(context).foodReconnectingBody,
                textAlign: TextAlign.center,
                style: textTheme.bodyMedium?.copyWith(
                  color: DealGoColors.textSecondary,
                ),
              ),
              if (current != null) ...[
                const SizedBox(height: DealGoSpacing.s16),
                FoodPanel(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        AppLocalizations.of(context).foodOrderInProgress,
                        style: textTheme.titleMedium,
                      ),
                      const SizedBox(height: DealGoSpacing.s8),
                      FoodMoneyRow(
                        label: AppLocalizations.of(context)
                            .merchantOrderRefLabel,
                        amount: shortRef(current.id),
                      ),
                      FoodMoneyRow(
                        label: AppLocalizations.of(context)
                            .merchantFoodValueLabel,
                        amount: formatVnd(current.subtotalVnd),
                      ),
                      FoodMoneyRow(
                        label: AppLocalizations.of(context).driverDeliveryFare,
                        amount: formatVnd(current.deliveryFareVnd),
                      ),
                      FoodMoneyRow(
                        label: AppLocalizations.of(context).foodCustomerPays,
                        amount: formatVnd(current.totalVnd),
                        emphasize: true,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: DealGoSpacing.s12),
                FoodPanel(
                  child: FoodMoneyRow(
                    label: AppLocalizations.of(context).foodLastKnownStatus,
                    amount: foodTrackingTitle(
                      AppLocalizations.of(context),
                      current.stage,
                    ),
                  ),
                ),
              ],
              const SizedBox(height: DealGoSpacing.s12),
              FoodNote(
                message: AppLocalizations.of(context).foodTrackingReconnectNote,
                tone: FoodNoteTone.amber,
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.all(DealGoDimensions.pageGutter),
          child: DealGoPrimaryButton(
            key: const Key('food-tracking-retry'),
            label: AppLocalizations.of(context).actionRetry,
            isLoading: busy,
            onPressed: onRetry,
          ),
        ),
      ],
    );
  }
}

/// Header copy follows the real delivery phase: READY waits for a driver,
/// ASSIGNED is the driver→store approach, PICKED_UP is store→customer.
String foodTrackingTitle(
  AppLocalizations l10n,
  FoodTrackingStage stage, {
  String? status,
}) {
  if (stage == FoodTrackingStage.onTheWay) {
    switch (status) {
      case 'READY':
        return l10n.foodStageFindingDriver;
      case 'ASSIGNED':
        return l10n.foodStageDriverToStore;
      case 'PICKED_UP':
        return l10n.foodStageDeliveringToYou;
    }
  }
  return switch (stage) {
    FoodTrackingStage.preparing => l10n.foodStagePreparing,
    FoodTrackingStage.onTheWay => l10n.foodStageOnTheWay,
    FoodTrackingStage.delivered => l10n.foodInvoiceDelivered,
    FoodTrackingStage.failed => l10n.foodStageFailed,
    FoodTrackingStage.cancelled => l10n.foodStageCancelled,
    FoodTrackingStage.unknown => l10n.foodStageUnknown,
  };
}

/// DEC-PROD-036: the customer gives this server-issued code to the courier on arrival.
class FoodDeliveryCodePanel extends StatelessWidget {
  const FoodDeliveryCodePanel({required this.code, super.key});

  final String code;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final textTheme = Theme.of(context).textTheme;
    return FoodPanel(
      key: const Key('food-delivery-code-panel'),
      color: DealGoColors.subtlePurple,
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(l10n.foodDeliveryCodeTitle, style: textTheme.titleMedium),
                const SizedBox(height: DealGoSpacing.s4),
                Text(
                  l10n.foodDeliveryCodeHint,
                  style: textTheme.bodySmall?.copyWith(
                    color: DealGoColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: DealGoSpacing.s12),
          Text(
            code,
            key: const Key('food-delivery-code'),
            style: textTheme.headlineMedium?.copyWith(
              fontWeight: FontWeight.w800,
              letterSpacing: 6,
              color: DealGoColors.primary,
            ),
          ),
        ],
      ),
    );
  }
}

/// Store pickup + dropoff (+ live driver via [LiveDriverMap]) for on-the-way orders.
class _FoodOnTheWayMap extends StatelessWidget {
  const _FoodOnTheWayMap({required this.order});

  final FoodOrderDetail order;

  @override
  Widget build(BuildContext context) {
    final pickup = order.pickup;
    final dropoff = order.dropoff;
    final markers = <MapLatLng>[
      if (pickup != null) MapLatLng(lat: pickup.lat, lng: pickup.lng),
      MapLatLng(lat: dropoff.lat, lng: dropoff.lng),
    ];
    final center = pickup != null
        ? MapLatLng(
            lat: (pickup.lat + dropoff.lat) / 2,
            lng: (pickup.lng + dropoff.lng) / 2,
          )
        : MapLatLng(lat: dropoff.lat, lng: dropoff.lng);
    final tracking =
        order.assignedDriverId != null &&
        (order.status == 'ASSIGNED' || order.status == 'PICKED_UP');
    final l10n = AppLocalizations.of(context);
    final chipLabel = tracking
        ? l10n.foodTrackingMapChip
        : l10n.foodTrackingMapWaitingDriver;
    return Stack(
      fit: StackFit.expand,
      children: [
        Builder(
          builder: (context) {
            final dropoff = MapLatLng(
              lat: order.dropoff.lat,
              lng: order.dropoff.lng,
            );
            final pickedUp = order.status == 'PICKED_UP';
            final phase = pickedUp
                ? LiveRoutePhase.toDropoff
                : LiveRoutePhase.toPickup;
            final liveTo = pickedUp
                ? dropoff
                : (pickup != null
                      ? MapLatLng(lat: pickup.lat, lng: pickup.lng)
                      : dropoff);
            final shownMarkers = pickedUp ? <MapLatLng>[dropoff] : markers;
            return LiveDriverMap(
              job: TrackedJob.food,
              sheetFraction: 0.48,
              id: order.id,
              tracking: tracking,
              center: center,
              markers: shownMarkers,
              route: (order.route ?? RouteGeometry.unavailable).polylineOr(
                markers.length >= 2 ? markers : const [],
              ),
              roadFollowed: order.route?.hasRoadPolyline ?? false,
              phase: phase,
              liveRouteTo: liveTo,
              serverRoute: pickedUp ? null : order.approachRoute,
              pulseRoute: true,
              firstMarkerIsPickup: !pickedUp && pickup != null,
            );
          },
        ),
        // Sits right of the TrackingScaffold back button (s12 + 48 + s8) so the
        // status chip never slides under it or the top bar (same row as ride).
        // Live phases already name the leg in the sheet headline; the chip
        // only flags the waiting-for-driver state to avoid duplicate text.
        if (!tracking)
          Positioned(
            top: DealGoSpacing.s8 + 10,
            left: DealGoSpacing.s12 + 48 + DealGoSpacing.s8,
            right: DealGoSpacing.s12 + 48 + DealGoSpacing.s8,
            child: Align(
              alignment: Alignment.centerLeft,
              child: DealGoChip(
                key: Key(
                  tracking
                      ? 'food-tracking-map-chip'
                      : 'food-tracking-map-waiting',
                ),
                label: chipLabel,
                tone: tracking
                    ? DealGoChipTone.neutral
                    : DealGoChipTone.warning,
              ),
            ),
          ),
        if (pickup == null && !tracking)
          Positioned(
            left: DealGoSpacing.s12,
            right: DealGoSpacing.s12,
            bottom: DealGoSpacing.s12,
            child: DecoratedBox(
              key: const Key('food-tracking-map-empty'),
              decoration: BoxDecoration(
                color: DealGoColors.card.withValues(alpha: 0.94),
                borderRadius: BorderRadius.circular(DealGoRadius.input),
                border: Border.all(color: DealGoColors.border),
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: DealGoSpacing.s12,
                  vertical: DealGoSpacing.s8,
                ),
                child: Text(
                  l10n.foodTrackingMapEmptyHint,
                  style: Theme.of(context).textTheme.labelMedium
                      ?.copyWith(fontWeight: FontWeight.w600),
                ),
              ),
            ),
          ),
      ],
    );
  }
}
