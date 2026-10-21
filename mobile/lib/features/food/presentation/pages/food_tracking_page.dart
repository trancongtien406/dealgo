import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../driver_card/domain/driver_card.dart';
import '../../../driver_card/presentation/driver_card_tile.dart';

import '../../../../core/design_system/components/dealgo_banner.dart';
import '../../../../core/design_system/components/dealgo_chip.dart';
import '../../../../core/design_system/components/dealgo_primary_button.dart';
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
import '../../domain/entities/food_models.dart';
import '../../domain/entities/food_money.dart';
import '../../domain/usecases/get_food_order.dart';
import '../utils/food_routes.dart';
import '../cubit/food_tracking_cubit.dart';
import '../widgets/food_reject_reason.dart';
import '../widgets/food_widgets.dart';
import '../../../../core/design_system/icons/dealgo_icons.dart';
import '../../../../core/format/short_ref.dart';
import '../../../../core/design_system/components/dealgo_app_header.dart';
import '../../../../core/design_system/components/dealgo_state_view.dart';

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
    );
  }

  Future<void> _openVoice(BuildContext context, String orderId) {
    return showVoiceCallSheet(
      context: context,
      kind: VoiceThreadKind.foodOrder,
      resourceId: orderId,
      accessToken: currentAccessToken(context),
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
            return _FoodLive(
              order: order,
              busy: busy,
              onBack: () => _back(context),
              onRefresh: () => context.read<FoodTrackingCubit>().refresh(),
              onCancelStub: () => context.push(FoodRoutes.cancel(orderId)),
              onOpenChat: () => _openChat(context, orderId),
              onOpenVoice: () => _openVoice(context, orderId),
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
    required this.onOpenVoice,
  });

  final FoodOrderDetail? order;
  final bool busy;
  final VoidCallback onBack;
  final VoidCallback onRefresh;
  final VoidCallback onCancelStub;
  final VoidCallback onOpenChat;
  final VoidCallback onOpenVoice;

  @override
  Widget build(BuildContext context) {
    final current = order;
    final textTheme = Theme.of(context).textTheme;
    final title = current == null
        ? AppLocalizations.of(context).foodTrackingTitle
        : foodTrackingTitle(AppLocalizations.of(context), current.stage);
    return Column(
      children: [
        DealGoAppHeader(
          title: AppLocalizations.of(context).foodTrackingTitle,
          onBack: onBack,
          trailing: IconButton(
            key: const Key('food-tracking-retry'),
            tooltip: AppLocalizations.of(context).actionReload,
            onPressed: busy ? null : onRefresh,
            icon: const Icon(DealGoIcons.refresh),
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
                FoodPanel(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              AppLocalizations.of(context)
                                  .foodTrackingStatusTitle,
                              style: textTheme.titleMedium,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: DealGoSpacing.s8),
                      Text(
                        '${AppLocalizations.of(context).foodInvoiceOrderId} ${shortRef(current.id)}',
                        key: ValueKey(current.stage),
                        style: textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: DealGoSpacing.s8),
                      DealGoChip(
                        label: title,
                        tone: switch (current.stage) {
                          FoodTrackingStage.cancelled ||
                          FoodTrackingStage.failed => DealGoChipTone.danger,
                          FoodTrackingStage.unknown => DealGoChipTone.neutral,
                          _ => DealGoChipTone.success,
                        },
                      ),
                      if (current.stage == FoodTrackingStage.preparing &&
                          current.estimatedReadyAt != null) ...[
                        const SizedBox(height: DealGoSpacing.s8),
                        Text(
                          AppLocalizations.of(context).foodTrackingReadyBy(
                            MaterialLocalizations.of(context).formatTimeOfDay(
                              TimeOfDay.fromDateTime(
                                current.estimatedReadyAt!.toLocal(),
                              ),
                              alwaysUse24HourFormat: true,
                            ),
                          ),
                          key: const Key('food-tracking-ready-by'),
                          style: textTheme.bodyMedium?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                      if (current.cancelReason case final reason?) ...[
                        const SizedBox(height: DealGoSpacing.s12),
                        DealGoBanner(
                          key: const Key('food-tracking-reject-reason'),
                          tone: DealGoBannerTone.warning,
                          title: AppLocalizations.of(context).foodRejectedTitle,
                          message: foodCancelReasonText(
                            AppLocalizations.of(context),
                            reason,
                          ),
                        ),
                      ],
                      const SizedBox(height: DealGoSpacing.s12),
                      FoodMoneyRow(
                        label: AppLocalizations.of(context).foodInvoiceStore,
                        amount: current.storeName ?? '—',
                      ),
                      Text(
                        AppLocalizations.of(context).foodTrackingDeliverTo,
                        style: textTheme.bodySmall,
                      ),
                      Text(
                        current.dropoff.label,
                        style: textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
                if (current.stage == FoodTrackingStage.onTheWay) ...[
                  const SizedBox(height: DealGoSpacing.s12),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(DealGoRadius.card),
                    child: SizedBox(
                      height: 160,
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                          LiveDriverMap(
                            job: TrackedJob.food,
                            id: current.id,
                            tracking:
                                current.assignedDriverId != null &&
                                (current.status == 'ASSIGNED' ||
                                    current.status == 'PICKED_UP'),
                            center: MapLatLng(
                              lat: current.dropoff.lat,
                              lng: current.dropoff.lng,
                            ),
                            markers: [
                              MapLatLng(
                                lat: current.dropoff.lat,
                                lng: current.dropoff.lng,
                              ),
                            ],
                          ),
                          Positioned(
                            top: DealGoSpacing.s12,
                            left: DealGoSpacing.s12,
                            child: DealGoChip(
                              label: AppLocalizations.of(context)
                                  .foodTrackingMapChip,
                              tone: DealGoChipTone.neutral,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: DealGoSpacing.s12),
                  FoodPanel(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          AppLocalizations.of(context).foodTrackingDriverTitle,
                          style: textTheme.titleMedium,
                        ),
                        const SizedBox(height: DealGoSpacing.s12),
                        DriverCardTile(
                          job: DriverCardJob.foodOrder,
                          jobId: current.id,
                          accessToken: currentAccessToken(context) ?? '',
                          assigned: current.assignedDriverId != null,
                        ),
                      ],
                    ),
                  ),
                  if (current.deliveryCode case final code?) ...[
                    const SizedBox(height: DealGoSpacing.s12),
                    FoodDeliveryCodePanel(code: code),
                  ],
                ],
                if (current.stage == FoodTrackingStage.preparing ||
                    current.stage == FoodTrackingStage.onTheWay) ...[
                  const SizedBox(height: DealGoSpacing.s12),
                  FoodPanel(
                    color: DealGoColors.subtlePurple,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          AppLocalizations.of(context)
                              .foodTrackingPayOnDelivery,
                          style: textTheme.titleMedium,
                        ),
                        const SizedBox(height: DealGoSpacing.s8),
                        FoodMoneyRow(
                          label: AppLocalizations.of(context)
                              .foodTrackingCodDue,
                          amount: formatVnd(current.totalVnd),
                          emphasize: true,
                        ),
                        Text(
                          AppLocalizations.of(context).foodTrackingCodHint,
                          style: textTheme.bodySmall,
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ],
          ),
        ),
        if (current != null)
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
                if (current.stage == FoodTrackingStage.cancelled)
                  DealGoPrimaryButton(
                    key: const Key('food-cancelled-browse'),
                    label: AppLocalizations.of(context).foodCancelledBrowse,
                    onPressed: () => context.go('/customer/shop'),
                  )
                else
                  Row(
                    children: [
                      Expanded(
                        child: DealGoPrimaryButton(
                          key: const Key('food-open-chat'),
                          label: AppLocalizations.of(context).chatContact,
                          enabled: !busy,
                          onPressed: onOpenChat,
                        ),
                      ),
                      const SizedBox(width: DealGoSpacing.s8),
                      IconButton.filled(
                        key: const Key('food-open-voice'),
                        tooltip: AppLocalizations.of(context).voiceCall,
                        onPressed: busy ? null : onOpenVoice,
                        style: IconButton.styleFrom(
                          backgroundColor: DealGoColors.brandGreen,
                        ),
                        icon: const Icon(
                          DealGoIcons.phone,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                const SizedBox(height: DealGoSpacing.s8),
                TextButton(
                  key: const Key('food-open-invoice'),
                  onPressed: busy
                      ? null
                      : () => context.push(FoodRoutes.invoice(current.id)),
                  child: Text(AppLocalizations.of(context).foodInvoiceTitle),
                ),
                if (current.stage == FoodTrackingStage.preparing) ...[
                  TextButton(
                    key: const Key('food-open-cancel-reasons'),
                    onPressed: busy ? null : onCancelStub,
                    child: Text(AppLocalizations.of(context).foodCancelTitle),
                  ),
                ],
              ],
            ),
          ),
      ],
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
        DealGoAppHeader(title: AppLocalizations.of(context).foodTrackOrder, onBack: onBack),
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
                      Text(AppLocalizations.of(context).foodOrderInProgress, style: textTheme.titleMedium),
                      const SizedBox(height: DealGoSpacing.s8),
                      FoodMoneyRow(label: AppLocalizations.of(context).merchantOrderRefLabel, amount: shortRef(current.id)),
                      FoodMoneyRow(
                        label: AppLocalizations.of(context).merchantFoodValueLabel,
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
                    amount: foodTrackingTitle(AppLocalizations.of(context), current.stage),
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

String foodTrackingTitle(AppLocalizations l10n, FoodTrackingStage stage) {
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
