import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/design_system/components/dealgo_chip.dart';
import '../../../../core/design_system/components/dealgo_primary_button.dart';
import '../../../../core/design_system/components/dealgo_secondary_button.dart';
import '../../../../core/design_system/tokens/dealgo_tokens.dart';
import '../../../../core/maps/map_lat_lng.dart';
import '../../../../core/maps/map_port.dart';
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
import '../../domain/entities/ride_vehicle.dart';
import '../../domain/usecases/get_ride.dart';
import '../utils/ride_routes.dart';
import '../cubit/ride_tracking_cubit.dart';
import '../widgets/ride_widgets.dart';

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
            final offline = state is RideTrackingOffline;
            final busy = state.busy;
            if (loading) {
              return Column(
                children: [
                  RideScreenHeader(
                    title: 'Theo dõi tài xế',
                    onBack: () => _back(context),
                  ),
                  const Expanded(
                    child: Center(child: CircularProgressIndicator()),
                  ),
                ],
              );
            }
            if (offline) {
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
    final title = current == null
        ? 'Theo dõi tài xế'
        : switch (current.status) {
            RideStatus.assigned => 'Tài xế đang đến đón',
            RideStatus.negotiating => 'Đang chờ tài xế nhận chuyến',
            RideStatus.expired => 'Chuyến đã hết hạn',
            RideStatus.cancelled => 'Chuyến đã hủy',
          };
    final driverId = current?.assignedDriverId;
    final driverName = () {
      if (driverId == null || driverId.isEmpty) {
        return 'Nguyễn Văn Hùng';
      }
      if (driverId == 'driver-hung' || driverId.contains('hung')) {
        return 'Nguyễn Văn Hùng';
      }
      return 'Tài xế $driverId';
    }();
    final pickupCode = current == null ? '7294' : ridePickupCode(current.id);
    final quoteId = current == null
        ? 'Q-CAR-0007'
        : rideQuoteDisplayId(current.id);
    return Column(
      children: [
        RideScreenHeader(
          title: title,
          onBack: onBack,
          trailing: IconButton(
            key: const Key('ride-tracking-retry'),
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
                ClipRRect(
                  borderRadius: BorderRadius.circular(DealGoRadius.card),
                  child: SizedBox(
                    height: 200,
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
                            MapLatLng(
                              lat: rideSampleDropoffLat,
                              lng: rideSampleDropoffLng,
                            ),
                          ],
                        ),
                        Positioned(
                          top: DealGoSpacing.s12,
                          left: DealGoSpacing.s12,
                          child: DealGoChip(
                            label: AppLocalizations.of(context)
                                .rideTrackingEtaChip,
                            tone: DealGoChipTone.neutral,
                            leading: const Icon(Icons.directions_car, size: 14),
                          ),
                        ),
                        Positioned(
                          bottom: DealGoSpacing.s12,
                          right: DealGoSpacing.s12,
                          child: DealGoChip(
                            label: AppLocalizations.of(context)
                                .rideTrackingMovingChip,
                            selected: true,
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
                      const RideSectionTitle('Tài xế đã nhận chuyến'),
                      const SizedBox(height: DealGoSpacing.s12),
                      Row(
                        children: [
                          CircleAvatar(
                            backgroundColor: DealGoColors.subtlePurple,
                            child: Text(
                              driverName.substring(0, 1).toUpperCase(),
                              style: const TextStyle(
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
                                  driverName,
                                  style: Theme.of(context)
                                      .textTheme
                                      .titleMedium,
                                ),
                                Text(
                                  '⭐ 4,9 · Toyota Vios · Xe 4 chỗ',
                                  style: Theme.of(context).textTheme.bodySmall,
                                ),
                                const SizedBox(height: DealGoSpacing.s8),
                                const RideStatusChip(
                                  label: '43A-567.89',
                                  tone: RideChipTone.purple,
                                ),
                              ],
                            ),
                          ),
                          IconButton.filled(
                            key: const Key('ride-open-voice'),
                            tooltip: AppLocalizations.of(context).voiceCall,
                            onPressed: busy ? null : onOpenVoice,
                            style: IconButton.styleFrom(
                              backgroundColor: DealGoColors.primary,
                            ),
                            icon: const Icon(
                              Icons.call_outlined,
                              color: Colors.white,
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
                            icon: const Icon(Icons.chat_bubble_outline),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: DealGoSpacing.s12),
                RidePanel(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const RideSectionTitle('Thông tin chuyến đi'),
                      const SizedBox(height: DealGoSpacing.s12),
                      RideStopList(
                        pickup: current.pickup.label,
                        dropoff: current.dropoff.label,
                      ),
                      const SizedBox(height: DealGoSpacing.s12),
                      RideMoneyLine(
                        label: 'Giá đã chốt · $quoteId',
                        amount: agreed == null ? '—' : formatRideVnd(agreed),
                        emphasize: agreed != null,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: DealGoSpacing.s12),
                RidePanel(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const RideSectionTitle('Mã đón khách'),
                      Text(
                        'Chỉ cung cấp mã khi xe đến đúng biển số',
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
                                  Icons.check,
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
                  label: 'Xem biên nhận',
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
    return Column(
      children: [
        RideScreenHeader(
          title: 'Theo dõi tài xế',
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
              const RideStateHero(
                icon: Icons.wifi_off,
                iconColor: DealGoColors.warning,
                background: DealGoColors.amberSurface,
                title: 'Tạm mất kết nối vị trí',
                message: 'Thông tin đang hiển thị là lần tải cuối, không phải vị trí trực tiếp.',
              ),
              const SizedBox(height: DealGoSpacing.s16),
              if (current != null)
                RidePanel(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const RideSectionTitle('Thông tin chuyến'),
                      const SizedBox(height: DealGoSpacing.s8),
                      RideMoneyLine(
                        label: 'Điểm đón',
                        amount: current.pickup.label,
                      ),
                      RideMoneyLine(
                        label: 'Điểm đến',
                        amount: current.dropoff.label,
                      ),
                      const RideMoneyLine(
                        label: 'Phương tiện',
                        amount: rideVehicleLabel,
                      ),
                      if (agreed != null)
                        RideMoneyLine(
                          label: 'Giá đã chốt',
                          amount: formatRideVnd(agreed),
                        ),
                    ],
                  ),
                ),
              const SizedBox(height: DealGoSpacing.s12),
              const RideNote(
                message: 'Không suy ra tài xế đã tới điểm đón khi lần tải này thất bại.',
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
