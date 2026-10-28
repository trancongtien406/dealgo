import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../driver_card/domain/driver_card.dart';
import '../../../driver_card/presentation/driver_card_tile.dart';

import '../../../../core/design_system/components/dealgo_primary_button.dart';
import '../../../../core/design_system/tokens/dealgo_tokens.dart';
import '../../../../l10n/app_localizations.dart';
import '../../domain/entities/ride_money.dart';
import '../../domain/entities/ride_models.dart';
import '../../domain/entities/ride_vehicle.dart';
import '../../../promotion/domain/entities/voucher_quote.dart';
import '../../../promotion/presentation/widgets/voucher_field.dart';
import '../pages/ride_offer_detail_page.dart';
import '../utils/ride_routes.dart';
import 'ride_widgets.dart';
import '../../../../core/design_system/icons/dealgo_icons.dart';
import '../../../../core/design_system/components/dealgo_app_header.dart';

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
        DealGoAppHeader(
          title: AppLocalizations.of(context).rideDriverOffers,
          onBack: onBack,
        ),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.all(DealGoDimensions.pageGutter),
            child: RideOfflineNotice(
              detail: AppLocalizations.of(context).rideOffersLoadFailed,
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
    this.onRaiseFare,
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

  /// Raise the fare in place (null hides the button).
  final VoidCallback? onRaiseFare;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        DealGoAppHeader(
          title: AppLocalizations.of(context).rideDriverOffers,
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
                icon: DealGoIcons.hourglass,
                iconColor: DealGoColors.warning,
                background: DealGoColors.amberSurface,
                title: AppLocalizations.of(context).rideNoOffersTitle,
                message: AppLocalizations.of(context).rideNoOffersMessage,
              ),
              const SizedBox(height: DealGoSpacing.s16),
              RidePanel(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    RideSectionTitle(
                      AppLocalizations.of(context).rideCurrentRoute,
                    ),
                    const SizedBox(height: DealGoSpacing.s12),
                    RideStopList(
                      pickup: ride.pickup.label,
                      dropoff: ride.dropoff.label,
                      stops: [for (final s in ride.stops) s.point.label],
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
                      AppLocalizations.of(context).rideCurrentQuoteFare,
                    ),
                    const SizedBox(height: DealGoSpacing.s8),
                    RideMoneyLine(
                      label: AppLocalizations.of(context).rideTripCode,
                      amount: rideShortRef(ride.id),
                    ),
                    RideMoneyLine(
                      label: AppLocalizations.of(context).rideOfferedFare,
                      amount: formatRideVnd(ride.offeredFareVnd),
                      emphasize: true,
                    ),
                  ],
                ),
              ),
              if (offline) ...[
                const SizedBox(height: DealGoSpacing.s12),
                RideOfflineNotice(
                  detail: AppLocalizations.of(context).rideListRefreshFailed,
                ),
              ],
              if (message != null) ...[
                const SizedBox(height: DealGoSpacing.s12),
                RideNote(message: message!),
              ],
              if (onRaiseFare != null)
                TextButton(
                  key: const Key('ride-raise-fare'),
                  onPressed: busy ? null : onRaiseFare,
                  child: Text(AppLocalizations.of(context).rideRaiseFare),
                ),
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
            primaryLabel: AppLocalizations.of(context).rideChangeOffer,
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
      title: AppLocalizations.of(context).rideQuoteExpiredTitle,
      message: AppLocalizations.of(context).rideQuoteExpiredMessage,
      icon: DealGoIcons.timer,
      iconColor: DealGoColors.danger,
      background: DealGoColors.dangerSurface,
      ride: ride,
      badge: AppLocalizations.of(context).rideQuoteExpiredBadge,
      quoteLabel: AppLocalizations.of(context).rideOldFare,
      quoteAmount: formatRideVnd(ride.offeredFareVnd),
      onBack: onBack,
      secondaryLabel: AppLocalizations.of(context).rideChangeOffer,
      primaryLabel: AppLocalizations.of(context).rideFindNewOffers,
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
        title: AppLocalizations.of(context).rideOfferTakenTitle,
        message: AppLocalizations.of(context).rideOfferTakenMessage,
        icon: DealGoIcons.swapHoriz,
        iconColor: DealGoColors.warning,
        background: DealGoColors.amberSurface,
        ride: ride,
        taken: true,
        badge: AppLocalizations.of(context).rideOfferUnavailable,
        quoteLabel: AppLocalizations.of(context).ridePreviousOffer,
        quoteAmount: formatRideVnd(amount),
        onBack: onBack,
        secondaryLabel: AppLocalizations.of(context).rideRefreshList,
        primaryLabel: AppLocalizations.of(context).rideSeeOtherDrivers,
        onSecondary: onRefresh,
        onPrimary: onRefresh,
      );
    }
    return _QuoteState(
      title: AppLocalizations.of(context).rideQuoteExpiredTitle,
      message: AppLocalizations.of(context).rideQuoteExpiredMessage,
      icon: DealGoIcons.timer,
      iconColor: DealGoColors.danger,
      background: DealGoColors.dangerSurface,
      ride: ride,
      badge: AppLocalizations.of(context).rideQuoteExpiredBadge,
      quoteLabel: AppLocalizations.of(context).rideOldFare,
      quoteAmount: formatRideVnd(amount),
      onBack: onBack,
      secondaryLabel: AppLocalizations.of(context).rideChangeOffer,
      primaryLabel: AppLocalizations.of(context).rideFindNewOffers,
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
    required this.onBack,
    required this.secondaryLabel,
    required this.primaryLabel,
    required this.onSecondary,
    required this.onPrimary,
    this.taken = false,
  });

  final bool taken;
  final String title;
  final String message;
  final IconData icon;
  final Color iconColor;
  final Color background;
  final RideView ride;
  final String badge;
  final String quoteLabel;
  final String quoteAmount;
  final VoidCallback onBack;
  final String secondaryLabel;
  final String primaryLabel;
  final VoidCallback onSecondary;
  final VoidCallback onPrimary;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        DealGoAppHeader(
          title: AppLocalizations.of(context).rideOfferList,
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
                    RideSectionTitle(
                      AppLocalizations.of(context).rideCurrentRoute,
                    ),
                    const SizedBox(height: DealGoSpacing.s12),
                    RideStopList(
                      pickup: ride.pickup.label,
                      dropoff: ride.dropoff.label,
                      stops: [for (final s in ride.stops) s.point.label],
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
                      taken
                          ? AppLocalizations.of(context).rideOfferJustInvalid
                          : AppLocalizations.of(context).rideOfferExpiredShort,
                    ),
                    const SizedBox(height: DealGoSpacing.s8),
                    RideStatusChip(
                      label: badge,
                      tone: taken ? RideChipTone.warning : RideChipTone.danger,
                    ),
                    const SizedBox(height: DealGoSpacing.s8),
                    RideMoneyLine(
                      label: AppLocalizations.of(context).rideTripCode,
                      amount: rideShortRef(ride.id),
                    ),
                    RideMoneyLine(label: quoteLabel, amount: quoteAmount),
                  ],
                ),
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
        DealGoAppHeader(title: title, onBack: onBack),
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
    this.onRaiseFare,
    this.onDeclineSelected,
    this.onVoucherQuote,
    this.voucherCode,
    this.voucherDiscountVnd = 0,
    this.voucherEpoch = 0,
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

  /// Raise the fare while drivers are still bidding.
  final VoidCallback? onRaiseFare;

  /// Turn the selected price down (the driver may re-offer).
  final VoidCallback? onDeclineSelected;

  /// DEC-PROD-024: voucher quoted on the selected offer and redeemed with the selection.
  final ValueChanged<VoucherQuote?>? onVoucherQuote;
  final String? voucherCode;
  final int voucherDiscountVnd;

  /// Bumped by the page to reset the field after the server refuses the code.
  final int voucherEpoch;

  @override
  Widget build(BuildContext context) {
    final selected = _selected(offers, selectedOfferId);
    final l10n = AppLocalizations.of(context);
    final textTheme = Theme.of(context).textTheme;
    return Column(
      children: [
        DealGoAppHeader(
          title: AppLocalizations.of(context).rideDriverOffers,
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
              RidePanel(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    RideSectionTitle(
                      AppLocalizations.of(context).rideRouteAndFare,
                    ),
                    const SizedBox(height: DealGoSpacing.s12),
                    RideStopList(
                      pickup: ride.pickup.label,
                      dropoff: ride.dropoff.label,
                      stops: [for (final s in ride.stops) s.point.label],
                    ),
                    const SizedBox(height: DealGoSpacing.s12),
                    RideMoneyLine(
                      label: AppLocalizations.of(context).rideYourBidLabel,
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
                      AppLocalizations.of(context)
                          .rideOffersCount(offers.length),
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
                            AppLocalizations.of(context).rideLowestFirst,
                            style: textTheme.labelSmall?.copyWith(
                              color: DealGoColors.primary,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(width: 4),
                          const Icon(
                            DealGoIcons.chevronDown,
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
                  rideId: ride.id,
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
              if (onVoucherQuote != null && selected != null) ...[
                const SizedBox(height: DealGoSpacing.s12),
                RidePanel(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      RideSectionTitle(l10n.rideVoucherTitle),
                      const SizedBox(height: DealGoSpacing.s12),
                      VoucherField(
                        key: ValueKey('ride-voucher-$voucherEpoch'),
                        service: VoucherService.ride,
                        orderAmountVnd: selected.amountVnd,
                        accessToken: () => rideAccessToken(context),
                        formatAmount: formatRideVnd,
                        initialCode: voucherCode,
                        onQuote: onVoucherQuote,
                      ),
                      if (voucherDiscountVnd > 0) ...[
                        const SizedBox(height: DealGoSpacing.s12),
                        RideMoneyLine(
                          label: l10n.rideCashDueLabel,
                          amount: formatRideVnd(
                            rideCashAfterVoucher(
                              selected.amountVnd,
                              voucherDiscountVnd,
                            ),
                          ),
                          emphasize: true,
                        ),
                      ],
                    ],
                  ),
                ),
              ],
              if (offline) ...[
                const SizedBox(height: DealGoSpacing.s12),
                RideOfflineNotice(
                  detail: AppLocalizations.of(context).rideSelectOffline,
                ),
              ],
              if (message != null) ...[
                const SizedBox(height: DealGoSpacing.s12),
                RideNote(message: message!),
              ],
              if (onRaiseFare != null || onDeclineSelected != null)
                Wrap(
                  alignment: WrapAlignment.center,
                  children: [
                    if (onDeclineSelected != null && selected != null)
                      TextButton(
                        key: const Key('ride-decline-offer'),
                        onPressed: busy ? null : onDeclineSelected,
                        child: Text(l10n.rideDeclineOffer),
                      ),
                    if (onRaiseFare != null)
                      TextButton(
                        key: const Key('ride-raise-fare'),
                        onPressed: busy ? null : onRaiseFare,
                        child: Text(l10n.rideRaiseFare),
                      ),
                  ],
                ),
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
                ? AppLocalizations.of(context).rideSelectOfferPrompt
                : AppLocalizations.of(context)
                      .rideSelectOfferAmount(formatRideVnd(selected.amountVnd)),
            trailingIcon: DealGoIcons.arrowRight,
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

class _OfferCard extends StatelessWidget {
  const _OfferCard({
    required this.rideId,
    required this.offer,
    required this.selected,
    required this.onTap,
    required this.onOpenDetail,
  });

  final String rideId;
  final RideOffer offer;
  final bool selected;
  final VoidCallback onTap;
  final VoidCallback onOpenDetail;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final l10n = AppLocalizations.of(context);
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
                  Expanded(
                    child: DriverCardTile(
                      job: DriverCardJob.rideOffer,
                      jobId: rideId,
                      offerId: offer.id,
                      accessToken: rideAccessToken(context) ?? '',
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
                        label: rideOfferKindLabel(l10n, offer.kind),
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
