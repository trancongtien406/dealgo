import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/design_system/components/dealgo_chip.dart';
import '../../../../core/design_system/components/dealgo_primary_button.dart';
import '../../../../core/design_system/tokens/dealgo_tokens.dart';
import '../../../../core/maps/map_lat_lng.dart';
import '../../../../core/maps/map_port.dart';
import '../../../../core/realtime/snapshot_realtime.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../ride/domain/entities/ride_money.dart';
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
import '../widgets/food_widgets.dart';

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
            final offline = state is FoodTrackingOffline;
            final busy = state.busy;
            if (loading) {
              return Column(
                children: [
                  FoodScreenHeader(
                    title: 'Theo dõi đơn đồ ăn',
                    onBack: () => _back(context),
                  ),
                  const Expanded(
                    child: Center(child: CircularProgressIndicator()),
                  ),
                ],
              );
            }
            if (offline) {
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
        ? 'Theo dõi đơn đồ ăn'
        : foodTrackingTitle(current.stage);
    return Column(
      children: [
        FoodScreenHeader(
          title: 'Theo dõi đơn đồ ăn',
          onBack: onBack,
          trailing: IconButton(
            key: const Key('food-tracking-retry'),
            tooltip: 'Tải lại',
            onPressed: busy ? null : onRefresh,
            icon: const Icon(Icons.refresh),
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
                          DealGoChip(
                            label: AppLocalizations.of(context)
                                .foodTrackingSyncChip,
                            tone: DealGoChipTone.neutral,
                          ),
                        ],
                      ),
                      const SizedBox(height: DealGoSpacing.s8),
                      Text(
                        '${AppLocalizations.of(context).foodInvoiceOrderId} #${current.id}',
                        key: ValueKey(current.stage),
                        style: textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: DealGoSpacing.s8),
                      DealGoChip(label: title, tone: DealGoChipTone.success),
                      const SizedBox(height: DealGoSpacing.s12),
                      FoodMoneyRow(
                        label: AppLocalizations.of(context).foodInvoiceStore,
                        amount: current.lines.isEmpty
                            ? '—'
                            : current.lines.first.name,
                      ),
                      Text('Giao đến', style: textTheme.bodySmall),
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
                          context.read<MapPort>().buildMap(
                            center: const MapLatLng(
                              lat: rideSamplePickupLat,
                              lng: rideSamplePickupLng,
                            ),
                            markers: const [
                              MapLatLng(
                                lat: rideSamplePickupLat,
                                lng: rideSamplePickupLng,
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
                          Positioned(
                            bottom: DealGoSpacing.s12,
                            right: DealGoSpacing.s12,
                            child: DealGoChip(
                              label: AppLocalizations.of(context)
                                  .foodTrackingMapCity,
                              selected: true,
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
                        Row(
                          children: [
                            const CircleAvatar(
                              backgroundColor: DealGoColors.subtlePurple,
                              child: Text(
                                'A',
                                style: TextStyle(
                                  color: DealGoColors.primary,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ),
                            const SizedBox(width: DealGoSpacing.s12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    AppLocalizations.of(context)
                                        .foodTrackingDriverSample,
                                    style: textTheme.titleSmall,
                                  ),
                                  Text(
                                    AppLocalizations.of(context)
                                        .foodTrackingDriverMeta,
                                    style: textTheme.bodySmall,
                                  ),
                                ],
                              ),
                            ),
                            DealGoChip(
                              label: AppLocalizations.of(context)
                                  .foodTrackingVerified,
                              tone: DealGoChipTone.success,
                            ),
                          ],
                        ),
                        const SizedBox(height: DealGoSpacing.s12),
                        FoodMoneyRow(
                          label: AppLocalizations.of(context)
                              .foodTrackingEtaLabel,
                          amount: AppLocalizations.of(context)
                              .foodTrackingEtaSample,
                          emphasize: true,
                        ),
                      ],
                    ),
                  ),
                ],
                const SizedBox(height: DealGoSpacing.s12),
                FoodPanel(
                  color: DealGoColors.subtlePurple,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        AppLocalizations.of(context).foodTrackingPayOnDelivery,
                        style: textTheme.titleMedium,
                      ),
                      const SizedBox(height: DealGoSpacing.s8),
                      FoodMoneyRow(
                        label: AppLocalizations.of(context).foodTrackingCodDue,
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
                        Icons.call_outlined,
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
        FoodScreenHeader(
          title: 'Theo dõi đơn hàng',
          subtitle: 'DealGo · Biến thể trạng thái',
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
                  icon: Icons.wifi_off,
                  background: DealGoColors.amberSurface,
                  foreground: DealGoColors.warning,
                ),
              ),
              const SizedBox(height: DealGoSpacing.s16),
              Text(
                'Đang kết nối lại...',
                textAlign: TextAlign.center,
                style: textTheme.titleMedium,
              ),
              const SizedBox(height: DealGoSpacing.s8),
              Text(
                'Kết nối cập nhật hành trình đã tạm ngắt. Đơn của bạn vẫn được xử lý bởi hệ thống.',
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
                      Text('Đơn hàng đang xử lý', style: textTheme.titleMedium),
                      const SizedBox(height: DealGoSpacing.s8),
                      FoodMoneyRow(label: 'Mã đơn', amount: current.id),
                      FoodMoneyRow(
                        label: 'Tiền món',
                        amount: formatVnd(current.subtotalVnd),
                      ),
                      FoodMoneyRow(
                        label: 'Phí giao',
                        amount: formatVnd(current.deliveryFareVnd),
                      ),
                      FoodMoneyRow(
                        label: 'Khách thanh toán',
                        amount: formatVnd(current.totalVnd),
                        emphasize: true,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: DealGoSpacing.s12),
                FoodPanel(
                  child: FoodMoneyRow(
                    label: 'Trạng thái cập nhật lần cuối',
                    amount: current.status,
                  ),
                ),
              ],
              const SizedBox(height: DealGoSpacing.s12),
              const FoodNote(
                message: 'Khi kết nối lại, ứng dụng lấy trạng thái mới nhất từ backend thay vì phát lại sự kiện cũ.',
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
