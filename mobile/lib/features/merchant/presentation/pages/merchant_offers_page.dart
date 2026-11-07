import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../../core/design_system/components/dealgo_dialog.dart';
import '../../../../core/design_system/components/dealgo_refresh.dart';
import '../../../../core/design_system/components/dealgo_secondary_button.dart';
import '../../../../core/design_system/components/dealgo_skeleton.dart';
import '../../../../core/design_system/components/dealgo_state_view.dart';
import '../../../../core/design_system/components/dealgo_voucher_ticket.dart';
import '../../../../core/design_system/tokens/dealgo_tokens.dart';
import '../../../../core/l10n/api_error_text.dart';
import '../../../../core/motion/dealgo_motion_widgets.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../food/domain/entities/food_models.dart';
import '../../../food/domain/entities/food_money.dart';
import '../../../food/presentation/widgets/store_meta.dart';
import '../../domain/merchant_offers.dart';
import '../utils/merchant_routes.dart';
import '../widgets/merchant_widgets.dart';

StoreOffer _asStoreOffer(MerchantOffer offer) => StoreOffer(
  id: offer.id,
  code: offer.code,
  name: offer.name,
  kind: offer.kind,
  discountValue: offer.discountValue,
  maxDiscountVnd: offer.maxDiscountVnd,
  minOrderVnd: offer.minOrderVnd,
  endsAt: offer.endsAt,
);

/// M040 — the store's own offers: list, pause / resume / end, create.
class MerchantOffersPage extends StatefulWidget {
  const MerchantOffersPage({super.key});

  @override
  State<MerchantOffersPage> createState() => _MerchantOffersPageState();
}

class _MerchantOffersPageState extends State<MerchantOffersPage> {
  List<MerchantOffer>? _offers;
  Object? _error;
  String? _busyId;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    setState(() => _error = null);
    try {
      final offers = await context.read<MerchantOfferRepository>().list(
        accessToken: merchantAccessToken(context) ?? '',
      );
      if (mounted) setState(() => _offers = offers);
    } catch (error) {
      if (mounted) setState(() => _error = error);
    }
  }

  Future<void> _create() async {
    final created = await context.push<MerchantOffer>(MerchantRoutes.offerNew);
    if (created != null && mounted) {
      setState(() => _offers = [created, ...?_offers]);
    }
  }

  Future<void> _setStatus(MerchantOffer offer, MerchantOfferStatus to) async {
    final l10n = AppLocalizations.of(context);
    if (to == MerchantOfferStatus.ended) {
      final ok = await showDealGoConfirmDialog(
        context: context,
        title: l10n.merchantOfferEndConfirm(offer.name),
        confirmLabel: l10n.merchantOfferEnd,
        cancelLabel: l10n.actionCancel,
        confirmTone: DealGoDialogPrimaryTone.danger,
        confirmKey: const Key('merchant-offer-end-confirm'),
      );
      if (!ok || !mounted) return;
    }
    setState(() => _busyId = offer.id);
    try {
      final updated = await context.read<MerchantOfferRepository>().setStatus(
        accessToken: merchantAccessToken(context) ?? '',
        offerId: offer.id,
        status: to,
      );
      if (!mounted) return;
      setState(() {
        _offers = [
          for (final o in _offers ?? const <MerchantOffer>[])
            o.id == updated.id ? updated : o,
        ];
      });
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(apiErrorText(l10n, error))));
      }
    } finally {
      if (mounted) setState(() => _busyId = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final offers = _offers;
    final now = DateTime.now();
    final live = offers?.where((o) => o.isLive(now)).length ?? 0;
    final full = live >= merchantOfferLiveLimit;
    final Widget body;
    if (_error != null && offers == null) {
      body = DealGoRefresh(
        onRefresh: _load,
        child: DealGoStateView.failure(
          context,
          onRetry: _load,
          cause: _error,
          message: apiErrorText(l10n, _error),
        ),
      );
    } else if (offers == null) {
      body = const DealGoSkeletonList(itemCount: 3);
    } else if (offers.isEmpty) {
      body = DealGoRefresh(
        onRefresh: _load,
        child: DealGoStateView(
          key: const Key('merchant-offers-empty'),
          art: DealGoStateArt.noVouchers,
          title: l10n.merchantOffersEmpty,
        ),
      );
    } else {
      body = DealGoRefresh(
        onRefresh: _load,
        child: ListView.separated(
          padding: const EdgeInsets.all(DealGoDimensions.pageGutter),
          itemCount: offers.length + (full ? 1 : 0),
          separatorBuilder: (context, index) =>
              const SizedBox(height: DealGoSpacing.s12),
          itemBuilder: (context, index) {
            if (full && index == 0) {
              return MerchantNote(
                tone: MerchantNoteTone.warning,
                message: l10n.merchantOfferLimitReached(merchantOfferLiveLimit),
              );
            }
            final offer = offers[index - (full ? 1 : 0)];
            return DealGoStaggerIn(
              index: index,
              child: _OfferCard(
                offer: offer,
                now: now,
                busy: _busyId == offer.id,
                onStatus: (to) => _setStatus(offer, to),
              ),
            );
          },
        ),
      );
    }
    return MerchantPageFrame(
      title: l10n.merchantOffersTitle,
      onBack: () => merchantBack(context),
      body: body,
      footer: offers == null
          ? null
          : MerchantPrimaryBar(
              label: l10n.merchantOffersCreate,
              buttonKey: const Key('merchant-offer-create'),
              enabled: !full,
              onPressed: _create,
            ),
    );
  }
}

class _OfferCard extends StatelessWidget {
  const _OfferCard({
    required this.offer,
    required this.now,
    required this.busy,
    required this.onStatus,
  });

  final MerchantOffer offer;
  final DateTime now;
  final bool busy;
  final ValueChanged<MerchantOfferStatus> onStatus;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final textTheme = Theme.of(context).textTheme;
    final date = DateFormat('dd/MM/yyyy');
    final live = offer.isLive(now);
    final (statusLabel, tone) = !live
        ? (l10n.merchantOfferStatusEnded, MerchantChipTone.neutral)
        : offer.status == MerchantOfferStatus.paused
        ? (l10n.merchantOfferStatusPaused, MerchantChipTone.warning)
        : offer.isUpcoming(now)
        ? (l10n.merchantOfferStatusUpcoming, MerchantChipTone.neutral)
        : (l10n.merchantOfferStatusActive, MerchantChipTone.green);
    final used = offer.usageLimit > 0
        ? (offer.usedCount / offer.usageLimit).clamp(0.0, 1.0)
        : 0.0;
    final cap = offer.maxDiscountVnd;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        DealGoVoucherTicket(
          key: Key('merchant-offer-${offer.id}'),
          headline: storeOfferHeadline(l10n, _asStoreOffer(offer)),
          caption: offer.code,
          title: offer.name,
          accent: DealGoColors.danger,
          dimmed: !live,
          conditions: [
            if (offer.minOrderVnd > 0)
              l10n.voucherMinOrder(formatVnd(offer.minOrderVnd)),
            if (offer.kind == StoreOfferKind.percentage && cap != null)
              l10n.voucherCap(formatVnd(cap)),
            '${date.format(offer.startsAt)} – ${date.format(offer.endsAt)}',
          ],
          footer: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              MerchantChip(label: statusLabel, tone: tone),
              const SizedBox(height: DealGoSpacing.s8),
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: used,
                  minHeight: 6,
                  color: DealGoColors.danger,
                  backgroundColor: DealGoColors.dangerSurface,
                ),
              ),
              const SizedBox(height: DealGoSpacing.s4),
              Text(
                l10n.merchantOfferUsage(offer.usedCount, offer.usageLimit),
                style: textTheme.labelSmall,
              ),
            ],
          ),
        ),
        if (live) ...[
          const SizedBox(height: DealGoSpacing.s12),
          IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(
                  child: DealGoSecondaryButton(
                    key: Key('merchant-offer-toggle-${offer.id}'),
                    compact: true,
                    label: offer.status == MerchantOfferStatus.paused
                        ? l10n.merchantOfferResume
                        : l10n.merchantOfferPause,
                    enabled: !busy,
                    onPressed: () => onStatus(
                      offer.status == MerchantOfferStatus.paused
                          ? MerchantOfferStatus.active
                          : MerchantOfferStatus.paused,
                    ),
                  ),
                ),
                const SizedBox(width: DealGoSpacing.s12),
                Expanded(
                  child: DealGoSecondaryButton(
                    key: Key('merchant-offer-end-${offer.id}'),
                    compact: true,
                    tone: DealGoSecondaryTone.danger,
                    label: l10n.merchantOfferEnd,
                    enabled: !busy,
                    onPressed: () => onStatus(MerchantOfferStatus.ended),
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }
}
