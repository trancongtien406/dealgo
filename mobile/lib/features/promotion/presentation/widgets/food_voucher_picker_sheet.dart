import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../../core/design_system/components/dealgo_state_view.dart';
import '../../../../core/design_system/components/dealgo_voucher_ticket.dart';
import '../../../../core/design_system/tokens/dealgo_tokens.dart';
import '../../../../core/motion/dealgo_motion_widgets.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../food/domain/entities/food_money.dart';
import '../../../food/presentation/widgets/store_meta.dart' as meta;
import '../../domain/entities/available_voucher.dart';
import '../../domain/entities/voucher_discount.dart';

/// Estimated saving of [voucher] on this cart; the server still prices it.
int voucherEstimatedSaving(
  AvailableVoucher voucher, {
  required int orderAmountVnd,
  required int deliveryFeeVnd,
}) {
  final raw = switch (voucher.kind) {
    VoucherDiscountKind.fixedAmount => voucher.discountValue,
    VoucherDiscountKind.percentage => percentVoucherDiscountVnd(
      orderAmountVnd,
      voucher.discountValue,
      voucher.maxDiscountVnd,
    ),
    VoucherDiscountKind.deliveryDiscount =>
      voucher.discountValue < deliveryFeeVnd
          ? voucher.discountValue
          : deliveryFeeVnd,
  };
  final cap = voucher.maxDiscountVnd;
  final capped = cap != null && raw > cap ? cap : raw;
  final ceiling = voucher.kind == VoucherDiscountKind.deliveryDiscount
      ? deliveryFeeVnd
      : orderAmountVnd;
  return capped.clamp(0, ceiling < 0 ? 0 : ceiling);
}

/// Ticket stub headline shared by the checkout picker and the discovery wall.
String voucherHeadlineLabel(AppLocalizations l10n, AvailableVoucher voucher) =>
    switch (voucher.kind) {
      VoucherDiscountKind.percentage => l10n.voucherPercent(
        voucher.discountValue,
      ),
      VoucherDiscountKind.fixedAmount => l10n.voucherFixed(
        meta.shortVnd(voucher.discountValue),
      ),
      VoucherDiscountKind.deliveryDiscount => l10n.voucherDelivery(
        meta.shortVnd(voucher.discountValue),
      ),
    };

/// Available food vouchers (`GET /v1/promotions/available`) as coupon cards:
/// estimated saving, unmet minimum, and the best pick first. Picking a code
/// returns it to checkout; the field still asks the server to price it.
class FoodVoucherPickerSheet extends StatefulWidget {
  const FoodVoucherPickerSheet({
    required this.load,
    this.orderAmountVnd = 0,
    this.deliveryFeeVnd = 0,
    this.selectedCode,
    super.key,
  });

  final Future<List<AvailableVoucher>> Function() load;
  final int orderAmountVnd;
  final int deliveryFeeVnd;

  /// Code already on the order: its ticket reads "Đã dùng".
  final String? selectedCode;

  @override
  State<FoodVoucherPickerSheet> createState() => _FoodVoucherPickerSheetState();
}

class _FoodVoucherPickerSheetState extends State<FoodVoucherPickerSheet> {
  List<AvailableVoucher>? _items;
  Object? _failure;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _failure = null;
      _items = null;
    });
    try {
      final items = await widget.load();
      if (mounted) {
        setState(() => _items = items);
      }
    } on Object catch (error) {
      if (mounted) {
        setState(() {
          _failure = error;
          _items = const [];
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final items = _items;
    final failure = _failure;
    final height = MediaQuery.sizeOf(context).height * 0.72;
    return SafeArea(
      child: SizedBox(
        height: height,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(
                DealGoDimensions.pageGutter,
                DealGoSpacing.s16,
                DealGoDimensions.pageGutter,
                DealGoSpacing.s8,
              ),
              child: Text(
                l10n.accountVouchers,
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ),
            Expanded(
              child: items == null
                  ? const Center(
                      child: CircularProgressIndicator(
                        key: Key('checkout-vouchers-loading'),
                      ),
                    )
                  : failure != null
                  ? Padding(
                      padding: const EdgeInsets.all(DealGoSpacing.s16),
                      child: DealGoStateView.failure(
                        context,
                        key: const Key('checkout-vouchers-error'),
                        onRetry: _load,
                        cause: failure,
                      ),
                    )
                  : items.isEmpty
                  ? Padding(
                      padding: const EdgeInsets.all(DealGoSpacing.s16),
                      child: DealGoStateView(
                        key: const Key('checkout-vouchers-empty'),
                        art: DealGoStateArt.noVouchers,
                        title: l10n.vouchersEmptyTitle,
                        message: l10n.vouchersEmptyBody,
                      ),
                    )
                  : _CouponList(
                      items: items,
                      orderAmountVnd: widget.orderAmountVnd,
                      deliveryFeeVnd: widget.deliveryFeeVnd,
                      selectedCode: widget.selectedCode,
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CouponList extends StatelessWidget {
  const _CouponList({
    required this.items,
    required this.orderAmountVnd,
    required this.deliveryFeeVnd,
    required this.selectedCode,
  });

  final List<AvailableVoucher> items;
  final int orderAmountVnd;
  final int deliveryFeeVnd;
  final String? selectedCode;

  @override
  Widget build(BuildContext context) {
    final rows = [
      for (final voucher in items)
        (
          voucher: voucher,
          saving: voucherEstimatedSaving(
            voucher,
            orderAmountVnd: orderAmountVnd,
            deliveryFeeVnd: deliveryFeeVnd,
          ),
          short: voucher.minOrderVnd > orderAmountVnd
              ? voucher.minOrderVnd - orderAmountVnd
              : 0,
        ),
    ];
    // Usable first, biggest saving first; unmet minimums sink to the end.
    rows.sort((a, b) {
      final usable = (a.short == 0 ? 0 : 1).compareTo(b.short == 0 ? 0 : 1);
      if (usable != 0) return usable;
      final saving = b.saving.compareTo(a.saving);
      return saving != 0 ? saving : a.short.compareTo(b.short);
    });
    final best =
        rows.isNotEmpty && rows.first.short == 0 && rows.first.saving > 0
        ? rows.first.voucher.code
        : null;
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(
        DealGoDimensions.pageGutter,
        DealGoSpacing.s8,
        DealGoDimensions.pageGutter,
        DealGoSpacing.s24,
      ),
      itemCount: rows.length,
      separatorBuilder: (_, _) => const SizedBox(height: DealGoSpacing.s12),
      itemBuilder: (context, index) {
        final row = rows[index];
        return DealGoStaggerIn(
          index: index,
          child: _CouponCard(
            voucher: row.voucher,
            savingVnd: row.saving,
            shortVnd: row.short,
            best: row.voucher.code == best,
            selected: row.voucher.code == selectedCode,
          ),
        );
      },
    );
  }
}

class _CouponCard extends StatelessWidget {
  const _CouponCard({
    required this.voucher,
    required this.savingVnd,
    required this.shortVnd,
    required this.best,
    required this.selected,
  });

  final AvailableVoucher voucher;
  final int savingVnd;
  final int shortVnd;
  final bool best;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final textTheme = Theme.of(context).textTheme;
    final usable = shortVnd == 0;
    final delivery = voucher.kind == VoucherDiscountKind.deliveryDiscount;
    final accent = delivery ? DealGoColors.brandGreen : DealGoColors.primary;
    final locale = Localizations.localeOf(context).toLanguageTag();
    final cap = voucher.maxDiscountVnd;
    final pick = usable ? () => Navigator.of(context).pop(voucher.code) : null;
    return DealGoPressScale(
      child: DealGoVoucherTicket(
        tapKey: Key('checkout-voucher-${voucher.code}'),
        headline: voucherHeadlineLabel(l10n, voucher),
        caption: voucher.code,
        title: voucher.name,
        conditions: [
          if (voucher.minOrderVnd > 0)
            l10n.voucherMinOrder(formatVnd(voucher.minOrderVnd)),
          if (voucher.kind == VoucherDiscountKind.percentage && cap != null)
            l10n.voucherCap(formatVnd(cap)),
          l10n.voucherEnds(
            DateFormat('dd/MM/yyyy', locale).format(voucher.endsAt),
          ),
          l10n.voucherUsesLeft(voucher.usesLeft),
        ],
        accent: accent,
        dimmed: !usable,
        highlighted: selected || best,
        onTap: pick,
        footer: _CouponFooter(
          voucher: voucher,
          savingVnd: savingVnd,
          shortVnd: shortVnd,
          best: best,
          accent: accent,
          textTheme: textTheme,
        ),
        action: !usable
            ? null
            : selected
            ? DealGoTicketButton(
                key: Key('checkout-voucher-used-${voucher.code}'),
                label: l10n.voucherApplied,
                accent: accent,
                done: true,
              )
            : DealGoTicketButton(
                key: Key('checkout-voucher-use-${voucher.code}'),
                label: l10n.voucherPickerApply,
                accent: accent,
                onPressed: pick,
              ),
      ),
    );
  }
}

class _CouponFooter extends StatelessWidget {
  const _CouponFooter({
    required this.voucher,
    required this.savingVnd,
    required this.shortVnd,
    required this.best,
    required this.accent,
    required this.textTheme,
  });

  final AvailableVoucher voucher;
  final int savingVnd;
  final int shortVnd;
  final bool best;
  final Color accent;
  final TextTheme textTheme;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final usable = shortVnd == 0;
    return Wrap(
      spacing: DealGoSpacing.s8,
      runSpacing: DealGoSpacing.s4,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        if (best)
          _Tag(
            key: const Key('checkout-voucher-best'),
            label: l10n.voucherBestPick,
            color: accent,
          ),
        if (usable && savingVnd > 0)
          Text(
            l10n.voucherSaveAmount(formatVnd(savingVnd)),
            key: Key('checkout-voucher-saving-${voucher.code}'),
            style: textTheme.labelLarge?.copyWith(
              color: DealGoColors.danger,
              fontWeight: FontWeight.w800,
            ),
          ),
        if (!usable)
          Text(
            l10n.voucherNeedMore(formatVnd(shortVnd)),
            style: textTheme.labelLarge?.copyWith(
              color: DealGoColors.warning,
              fontWeight: FontWeight.w700,
            ),
          ),
      ],
    );
  }
}

class _Tag extends StatelessWidget {
  const _Tag({required this.label, required this.color, super.key});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(DealGoRadius.pill),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: DealGoSpacing.s8,
          vertical: 2,
        ),
        child: Text(
          label,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 11,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
    );
  }
}
