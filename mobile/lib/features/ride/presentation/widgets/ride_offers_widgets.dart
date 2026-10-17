import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/design_system/components/dealgo_primary_button.dart';
import '../../../../core/design_system/tokens/dealgo_tokens.dart';
import '../../../../l10n/app_localizations.dart';
import '../../domain/entities/ride_money.dart';
import '../../domain/entities/ride_models.dart';
import '../../domain/entities/ride_vehicle.dart';
import '../pages/ride_offer_detail_page.dart';
import '../utils/ride_routes.dart';
import 'ride_widgets.dart';

class OfferBlock {
  const OfferBlock.expired({this.amountVnd}) : taken = false;
  const OfferBlock.taken({this.amountVnd}) : taken = true;

  final bool taken;
  final int? amountVnd;
}

class OfflineOffers extends StatelessWidget {
  const OfflineOffers({required this.onBack, required this.onRetry, super.key});

  final VoidCallback onBack;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        RideScreenHeader(
          title: 'Tài xế chào giá',
          subtitle: 'DealGo · Biến thể trạng thái',
          onBack: onBack,
        ),
        const Expanded(
          child: Padding(
            padding: EdgeInsets.all(DealGoDimensions.pageGutter),
            child: RideOfflineNotice(
              detail: 'Chưa tải được báo giá. Chuyến chưa được xác nhận.',
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.all(DealGoDimensions.pageGutter),
          child: DealGoPrimaryButton(
            label: AppLocalizations.of(context).actionRetry,
            onPressed: onRetry,
          ),
        ),
      ],
    );
  }
}

class EmptyOffers extends StatelessWidget {
  const EmptyOffers({
    required this.ride,
    required this.busy,
    required this.offline,
    required this.message,
    required this.onBack,
    required this.onRetry,
    required this.onChangeFare,
    required this.onCancel,
    super.key,
  });

  final RideView ride;
  final bool busy;
  final bool offline;
  final String? message;
  final VoidCallback onBack;
  final VoidCallback onRetry;
  final VoidCallback onChangeFare;
  final VoidCallback onCancel;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        RideScreenHeader(
          title: 'Tài xế chào giá',
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
                icon: Icons.hourglass_empty,
                iconColor: DealGoColors.warning,
                background: DealGoColors.amberSurface,
                title: 'Chưa có tài xế chào giá',
                message: 'Trong khu vực này chưa có báo giá hợp lệ cho yêu cầu hiện tại.',
              ),
              const SizedBox(height: DealGoSpacing.s16),
              RidePanel(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const RideSectionTitle('Hành trình đang chọn'),
                    const SizedBox(height: DealGoSpacing.s12),
                    RideStopList(
                      pickup: ride.pickup.label,
                      dropoff: ride.dropoff.label,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: DealGoSpacing.s12),
              RidePanel(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const RideSectionTitle('Giá của báo giá đang sử dụng'),
                    const SizedBox(height: DealGoSpacing.s8),
                    RideMoneyLine(
                      label: 'Mã báo giá',
                      amount: rideQuoteDisplayId(ride.id),
                    ),
                    RideMoneyLine(
                      label: 'Giá đề xuất',
                      amount: formatRideVnd(ride.offeredFareVnd),
                      emphasize: true,
                    ),
                    const RideMoneyLine(label: 'Phiên báo giá', amount: 'v1'),
                  ],
                ),
              ),
              const SizedBox(height: DealGoSpacing.s12),
              const RideNote(
                message: 'Có thể chỉnh giá đề xuất, mở rộng bán kính hoặc thử lại sau.',
              ),
              if (offline) ...[
                const SizedBox(height: DealGoSpacing.s12),
                const RideOfflineNotice(detail: 'Chưa làm mới được danh sách.'),
              ],
              if (message != null) ...[
                const SizedBox(height: DealGoSpacing.s12),
                RideNote(message: message!),
              ],
              TextButton(
                key: const Key('ride-empty-open-cancel'),
                onPressed: busy
                    ? null
                    : () => context.push(RideRoutes.cancel(ride.id)),
                child: Text(AppLocalizations.of(context).rideCancelTitle),
              ),
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
          child: RideDualActions(
            secondaryLabel: AppLocalizations.of(context).actionRetry,
            primaryLabel: 'Thay đổi đề xuất',
            enabled: !busy,
            onSecondary: onRetry,
            onPrimary: onChangeFare,
          ),
        ),
      ],
    );
  }
}

class ExpiredRide extends StatelessWidget {
  const ExpiredRide({
    required this.ride,
    required this.onBack,
    required this.onChangeFare,
    required this.onRefresh,
    super.key,
  });

  final RideView ride;
  final VoidCallback onBack;
  final VoidCallback onChangeFare;
  final VoidCallback onRefresh;

  @override
  Widget build(BuildContext context) {
    return _QuoteState(
      title: 'Báo giá đã hết hạn',
      message: 'Báo giá cũ không thể được chọn vì đã quá thời gian hiệu lực.',
      icon: Icons.timelapse,
      iconColor: DealGoColors.danger,
      background: DealGoColors.dangerSurface,
      ride: ride,
      badge: ride.status == RideStatus.expired ? ride.status.wire : 'EXPIRED',
      quoteLabel: 'Giá cũ (tham khảo)',
      quoteAmount: formatRideVnd(ride.offeredFareVnd),
      note: 'Phải lấy quoteId + version mới trước khi xác nhận; tuyệt đối không gửi lại báo giá cũ.',
      onBack: onBack,
      secondaryLabel: 'Thay đổi đề xuất',
      primaryLabel: 'Tìm báo giá mới',
      onSecondary: onChangeFare,
      onPrimary: onRefresh,
    );
  }
}

class BlockedOffers extends StatelessWidget {
  const BlockedOffers({
    required this.ride,
    required this.block,
    required this.onBack,
    required this.onChangeFare,
    required this.onRefresh,
    super.key,
  });

  final RideView ride;
  final OfferBlock block;
  final VoidCallback onBack;
  final VoidCallback onChangeFare;
  final VoidCallback onRefresh;

  @override
  Widget build(BuildContext context) {
    final amount = block.amountVnd ?? ride.offeredFareVnd;
    if (block.taken) {
      return _QuoteState(
        title: 'Tài xế đã nhận việc khác',
        message:
            'Báo giá bạn vừa chọn không còn khả dụng tại thời điểm xác nhận.',
        icon: Icons.swap_horiz,
        iconColor: DealGoColors.warning,
        background: DealGoColors.amberSurface,
        ride: ride,
        badge: 'Không còn khả dụng',
        quoteLabel: 'Giá chào trước đó',
        quoteAmount: formatRideVnd(amount),
        note:
            'Dữ liệu danh sách có thể đã cũ. Làm mới và chọn một đề nghị khác.',
        onBack: onBack,
        secondaryLabel: 'Làm mới danh sách',
        primaryLabel: 'Xem tài xế khác',
        onSecondary: onRefresh,
        onPrimary: onRefresh,
      );
    }
    return _QuoteState(
      title: 'Báo giá đã hết hạn',
      message: 'Báo giá cũ không thể được chọn vì đã quá thời gian hiệu lực.',
      icon: Icons.timelapse,
      iconColor: DealGoColors.danger,
      background: DealGoColors.dangerSurface,
      ride: ride,
      badge: 'EXPIRED',
      quoteLabel: 'Giá cũ (tham khảo)',
      quoteAmount: formatRideVnd(amount),
      note: 'Phải lấy quoteId + version mới trước khi xác nhận; tuyệt đối không gửi lại báo giá cũ.',
      onBack: onBack,
      secondaryLabel: 'Thay đổi đề xuất',
      primaryLabel: 'Tìm báo giá mới',
      onSecondary: onChangeFare,
      onPrimary: onRefresh,
    );
  }
}

class _QuoteState extends StatelessWidget {
  const _QuoteState({
    required this.title,
    required this.message,
    required this.icon,
    required this.iconColor,
    required this.background,
    required this.ride,
    required this.badge,
    required this.quoteLabel,
    required this.quoteAmount,
    required this.note,
    required this.onBack,
    required this.secondaryLabel,
    required this.primaryLabel,
    required this.onSecondary,
    required this.onPrimary,
  });

  final String title;
  final String message;
  final IconData icon;
  final Color iconColor;
  final Color background;
  final RideView ride;
  final String badge;
  final String quoteLabel;
  final String quoteAmount;
  final String note;
  final VoidCallback onBack;
  final String secondaryLabel;
  final String primaryLabel;
  final VoidCallback onSecondary;
  final VoidCallback onPrimary;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        RideScreenHeader(
          title: 'Danh sách báo giá',
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
              RideStateHero(
                icon: icon,
                iconColor: iconColor,
                background: background,
                title: title,
                message: message,
              ),
              const SizedBox(height: DealGoSpacing.s16),
              RidePanel(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const RideSectionTitle('Hành trình đang chọn'),
                    const SizedBox(height: DealGoSpacing.s12),
                    RideStopList(
                      pickup: ride.pickup.label,
                      dropoff: ride.dropoff.label,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: DealGoSpacing.s12),
              RidePanel(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    RideSectionTitle(
                      badge == 'Không còn khả dụng'
                          ? 'Báo giá vừa hết hiệu lực'
                          : 'Báo giá hết hạn',
                    ),
                    const SizedBox(height: DealGoSpacing.s8),
                    RideStatusChip(
                      label: badge,
                      tone: badge == 'Không còn khả dụng'
                          ? RideChipTone.warning
                          : RideChipTone.danger,
                    ),
                    const SizedBox(height: DealGoSpacing.s8),
                    RideMoneyLine(
                      label: 'Báo giá',
                      amount: rideQuoteDisplayId(ride.id),
                    ),
                    RideMoneyLine(label: quoteLabel, amount: quoteAmount),
                  ],
                ),
              ),
              const SizedBox(height: DealGoSpacing.s12),
              RideNote(message: note),
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
          child: RideDualActions(
            secondaryLabel: secondaryLabel,
            primaryLabel: primaryLabel,
            onSecondary: onSecondary,
            onPrimary: onPrimary,
          ),
        ),
      ],
    );
  }
}

class TerminalRide extends StatelessWidget {
  const TerminalRide({
    required this.title,
    required this.status,
    required this.message,
    required this.onBack,
    this.actionLabel,
    this.onAction,
    super.key,
  });

  final String title;
  final String status;
  final String message;
  final VoidCallback onBack;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    final action = onAction;
    final label = actionLabel;
    return Column(
      children: [
        RideScreenHeader(title: title, onBack: onBack),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.all(DealGoDimensions.pageGutter),
            child: Column(
              children: [
                RideStatusChip(label: status, tone: RideChipTone.purple),
                const SizedBox(height: DealGoSpacing.s16),
                Text(message, textAlign: TextAlign.center),
              ],
            ),
          ),
        ),
        if (action != null && label != null)
          Padding(
            padding: const EdgeInsets.all(DealGoDimensions.pageGutter),
            child: DealGoPrimaryButton(label: label, onPressed: action),
          ),
      ],
    );
  }
}

class OfferList extends StatelessWidget {
  const OfferList({
    required this.ride,
    required this.offers,
    required this.selectedOfferId,
    required this.busy,
    required this.offline,
    required this.message,
    required this.onBack,
    required this.onSelectOffer,
    required this.onConfirm,
    required this.onCancel,
    super.key,
  });

  final RideView ride;
  final List<RideOffer> offers;
  final String? selectedOfferId;
  final bool busy;
  final bool offline;
  final String? message;
  final VoidCallback onBack;
  final ValueChanged<String> onSelectOffer;
  final VoidCallback onConfirm;
  final VoidCallback onCancel;

  @override
  Widget build(BuildContext context) {
    final selected = _selected(offers, selectedOfferId);
    final textTheme = Theme.of(context).textTheme;
    return Column(
      children: [
        RideScreenHeader(title: 'Tài xế chào giá', onBack: onBack),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(
              DealGoDimensions.pageGutter,
              DealGoSpacing.s8,
              DealGoDimensions.pageGutter,
              DealGoSpacing.s16,
            ),
            children: [
              RidePanel(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const RideSectionTitle('Hành trình & giá đề xuất'),
                    const SizedBox(height: DealGoSpacing.s12),
                    RideStopList(
                      pickup: ride.pickup.label,
                      dropoff: ride.dropoff.label,
                    ),
                    const SizedBox(height: DealGoSpacing.s12),
                    RideMoneyLine(
                      label: 'Giá bạn đề xuất',
                      amount: formatRideVnd(ride.offeredFareVnd),
                      emphasize: true,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: DealGoSpacing.s16),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      '${offers.length} báo giá phù hợp',
                      style: textTheme.titleMedium,
                    ),
                  ),
                  DecoratedBox(
                    decoration: BoxDecoration(
                      color: DealGoColors.subtlePurple,
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: DealGoSpacing.s12,
                        vertical: DealGoSpacing.s8,
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            'Giá thấp nhất',
                            style: textTheme.labelSmall?.copyWith(
                              color: DealGoColors.primary,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(width: 4),
                          const Icon(
                            Icons.keyboard_arrow_down,
                            size: 16,
                            color: DealGoColors.primary,
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: DealGoSpacing.s12),
              for (final offer in offers) ...[
                _OfferCard(
                  offer: offer,
                  selected: offer.id == selectedOfferId,
                  onTap: () => onSelectOffer(offer.id),
                  onOpenDetail: () => context.push(
                    RideRoutes.offerDetail(ride.id, offerId: offer.id),
                    extra: RideOfferDetailArgs(ride: ride, offer: offer),
                  ),
                ),
                const SizedBox(height: DealGoSpacing.s12),
              ],
              const RideNote(
                message: 'Chỉ có báo giá bạn xác nhận mới tạo thành chuyến đi. Báo giá chưa chọn có thể hết hạn.',
              ),
              if (offline) ...[
                const SizedBox(height: DealGoSpacing.s12),
                const RideOfflineNotice(
                  detail: 'Chưa gửi được lựa chọn. Giá chuyến chưa được chốt.',
                ),
              ],
              if (message != null) ...[
                const SizedBox(height: DealGoSpacing.s12),
                RideNote(message: message!),
              ],
              TextButton(
                key: const Key('ride-offers-open-cancel'),
                onPressed: busy
                    ? null
                    : () => context.push(RideRoutes.cancel(ride.id)),
                child: Text(AppLocalizations.of(context).rideCancelTitle),
              ),
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
          child: DealGoPrimaryButton(
            key: const Key('ride-select-offer'),
            label: selected == null
                ? 'Chọn báo giá'
                : 'Xem tài xế ${_offerDriverLabel(selected)}',
            trailingIcon: Icons.arrow_forward,
            isLoading: busy,
            enabled: selected != null,
            onPressed: onConfirm,
          ),
        ),
      ],
    );
  }
}

RideOffer? _selected(List<RideOffer> offers, String? id) {
  for (final offer in offers) {
    if (offer.id == id) {
      return offer;
    }
  }
  return null;
}

String _offerDriverLabel(RideOffer offer) {
  final id = offer.driverId;
  if (id.isEmpty) {
    return 'tài xế';
  }
  if (id == 'driver-hung' || id.endsWith('-hung')) {
    return 'Nguyễn Văn Hùng';
  }
  if (id == 'driver-1' || id.contains('hung')) {
    return 'Nguyễn Văn Hùng';
  }
  return 'Tài xế $id';
}

class _OfferCard extends StatelessWidget {
  const _OfferCard({
    required this.offer,
    required this.selected,
    required this.onTap,
    required this.onOpenDetail,
  });

  final RideOffer offer;
  final bool selected;
  final VoidCallback onTap;
  final VoidCallback onOpenDetail;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final l10n = AppLocalizations.of(context);
    final name = _offerDriverLabel(offer);
    final initial = name.isEmpty ? '?' : name.substring(0, 1).toUpperCase();
    return Material(
      color: DealGoColors.card,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(DealGoRadius.card),
        side: BorderSide(
          color: selected ? DealGoColors.primary : DealGoColors.border,
          width: selected ? 1.6 : 1,
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        key: Key('ride-offer-${offer.id}'),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(DealGoSpacing.s16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  CircleAvatar(
                    backgroundColor: DealGoColors.subtlePurple,
                    child: Text(
                      initial,
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
                          name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: textTheme.titleMedium?.copyWith(fontSize: 16),
                        ),
                        Text(
                          '⭐ 4,9 · $rideVehicleLabel',
                          style: textTheme.bodySmall,
                        ),
                        Text(
                          '43A-567.89 · Đến đón sau 4 phút',
                          style: textTheme.bodySmall,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: DealGoSpacing.s8),
                  Text(
                    formatRideVnd(offer.amountVnd),
                    style: textTheme.titleMedium?.copyWith(
                      color: DealGoColors.primary,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: DealGoSpacing.s12),
              Row(
                children: [
                  Flexible(
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: RideStatusChip(
                        label: rideOfferKindLabel(offer.kind),
                        tone: offer.kind == RideOfferKind.accept
                            ? RideChipTone.green
                            : RideChipTone.neutral,
                      ),
                    ),
                  ),
                  const SizedBox(width: DealGoSpacing.s8),
                  Material(
                    color: DealGoColors.subtlePurple,
                    borderRadius: BorderRadius.circular(999),
                    child: InkWell(
                      key: Key('ride-offer-detail-${offer.id}'),
                      onTap: onOpenDetail,
                      borderRadius: BorderRadius.circular(999),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: DealGoSpacing.s12,
                          vertical: DealGoSpacing.s8,
                        ),
                        child: Text(
                          l10n.actionSeeDetail,
                          style: textTheme.labelSmall?.copyWith(
                            color: DealGoColors.primary,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
