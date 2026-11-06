import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/design_system/components/dealgo_card.dart';
import '../../../../core/design_system/components/dealgo_chip.dart';
import '../../../../core/design_system/components/dealgo_refresh.dart';
import '../../../../core/design_system/components/dealgo_state_view.dart';
import '../../../../core/design_system/icons/dealgo_icons.dart';
import '../../../../core/design_system/tokens/dealgo_tokens.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../food/domain/entities/food_money.dart';
import '../../../food/presentation/cubit/food_cart_cubit.dart';
import '../../../food/presentation/widgets/food_widgets.dart';
import '../../../shell/presentation/account_widgets.dart';
import '../../domain/entities/available_voucher.dart';
import '../../domain/entities/voucher_quote.dart';
import '../../domain/usecases/list_available_vouchers.dart';
import '../../../../core/design_system/components/dealgo_app_header.dart';

/// Customer vouchers (`GET /v1/promotions/available`). Only food checkout takes
/// a code today, so the list asks for FOOD (plus ALL) campaigns.
class VouchersPage extends StatefulWidget {
  const VouchersPage({super.key});

  @override
  State<VouchersPage> createState() => _VouchersPageState();
}

class _VouchersPageState extends State<VouchersPage> {
  List<AvailableVoucher>? _items;
  Object? _failure;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load({bool keepItems = false}) async {
    final token = currentAccessToken(context);
    if (token == null) {
      setState(() {
        _failure = null;
        _items = const [];
      });
      return;
    }
    setState(() {
      _failure = null;
      if (!keepItems) {
        _items = null;
      }
    });
    try {
      final items = await context.read<ListAvailableVouchers>()(
        accessToken: token,
        service: VoucherService.food,
      );
      if (mounted) setState(() => _items = items);
    } on Object catch (error) {
      if (mounted) {
        setState(() {
          _failure = error;
          _items = const [];
        });
      }
    }
  }

  void _use(AvailableVoucher voucher) {
    final l10n = AppLocalizations.of(context);
    Clipboard.setData(ClipboardData(text: voucher.code));
    FoodCartCubit? cart;
    try {
      cart = context.read<FoodCartCubit>();
    } on Object {
      cart = null;
    }
    cart?.applyVoucher(code: voucher.code);
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(l10n.vouchersUseDone(voucher.code))));
    context.go('/customer/shop');
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final items = _items;
    final failure = _failure;
    return Scaffold(
      backgroundColor: DealGoColors.canvas,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            DealGoAppHeader(title: l10n.accountVouchers),
            Expanded(
              child: items == null
                  ? const Center(
                      child: CircularProgressIndicator(
                        key: Key('vouchers-loading'),
                      ),
                    )
                  : DealGoRefresh(
                      onRefresh: () => _load(keepItems: true),
                      child: failure != null
                          ? Padding(
                              padding: const EdgeInsets.all(DealGoSpacing.s16),
                              child: DealGoStateView.failure(
                                context,
                                key: const Key('vouchers-error'),
                                onRetry: _load,
                                cause: failure,
                              ),
                            )
                          : items.isEmpty
                          ? Padding(
                              padding: const EdgeInsets.all(DealGoSpacing.s16),
                              child: DealGoStateView(
                                key: const Key('vouchers-empty'),
                                art: DealGoStateArt.noVouchers,
                                title: l10n.vouchersEmptyTitle,
                                message: l10n.vouchersEmptyBody,
                              ),
                            )
                          : ListView.separated(
                              padding: const EdgeInsets.fromLTRB(
                                DealGoDimensions.pageGutter,
                                DealGoSpacing.s16,
                                DealGoDimensions.pageGutter,
                                DealGoSpacing.s24,
                              ),
                              itemCount: items.length + 1,
                              separatorBuilder: (_, _) =>
                                  const SizedBox(height: DealGoSpacing.s12),
                              itemBuilder: (context, index) =>
                                  index == items.length
                                  ? Text(
                                      l10n.vouchersFootnote,
                                      style: Theme.of(
                                        context,
                                      ).textTheme.bodySmall,
                                    )
                                  : _VoucherCard(
                                      voucher: items[index],
                                      onUse: () => _use(items[index]),
                                    ),
                            ),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

String voucherHeadline(AppLocalizations l10n, AvailableVoucher v) =>
    switch (v.kind) {
      VoucherDiscountKind.percentage =>
        v.maxDiscountVnd == null
            ? l10n.voucherPercent(v.discountValue)
            : l10n.voucherPercentMax(
                v.discountValue,
                formatVnd(v.maxDiscountVnd!),
              ),
      VoucherDiscountKind.fixedAmount => l10n.voucherFixed(
        formatVnd(v.discountValue),
      ),
      VoucherDiscountKind.deliveryDiscount => l10n.voucherDelivery(
        formatVnd(v.discountValue),
      ),
    };

class _VoucherCard extends StatelessWidget {
  const _VoucherCard({required this.voucher, required this.onUse});

  final AvailableVoucher voucher;
  final VoidCallback onUse;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final textTheme = Theme.of(context).textTheme;
    final locale = Localizations.localeOf(context).toLanguageTag();
    final ends = voucher.endsAt;
    final endsText =
        '${ends.day.toString().padLeft(2, '0')}/${ends.month.toString().padLeft(2, '0')}/${ends.year}';
    return DealGoCard(
      key: Key('voucher-${voucher.code}'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              AccountToneIcon(
                icon: DealGoIcons.voucher,
                background: DealGoColors.subtlePurple,
                foreground: DealGoColors.primary,
              ),
              const SizedBox(width: DealGoSpacing.s12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      voucherHeadline(l10n, voucher),
                      style: textTheme.titleMedium?.copyWith(fontSize: 16),
                    ),
                    Text(voucher.name, style: textTheme.bodySmall),
                  ],
                ),
              ),
              DealGoChip(label: voucher.code, tone: DealGoChipTone.promo),
            ],
          ),
          if (voucher.description.isNotEmpty) ...[
            const SizedBox(height: DealGoSpacing.s8),
            Text(voucher.description, style: textTheme.bodySmall),
          ],
          const SizedBox(height: DealGoSpacing.s8),
          Text(
            [
              if (voucher.minOrderVnd > 0)
                l10n.voucherMinOrder(formatVnd(voucher.minOrderVnd)),
              l10n.voucherEnds(endsText),
              l10n.voucherUsesLeft(voucher.usesLeft),
            ].join(' · '),
            key: ValueKey('voucher-meta-$locale'),
            style: textTheme.labelSmall?.copyWith(
              color: DealGoColors.textSecondary,
            ),
          ),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton.icon(
              key: Key('voucher-use-${voucher.code}'),
              onPressed: onUse,
              icon: const Icon(DealGoIcons.restaurant, size: 18),
              label: Text(l10n.vouchersUse),
            ),
          ),
        ],
      ),
    );
  }
}
