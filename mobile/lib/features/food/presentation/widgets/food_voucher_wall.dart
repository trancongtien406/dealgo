import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../../core/design_system/components/dealgo_skeleton.dart';
import '../../../../core/design_system/components/dealgo_voucher_ticket.dart';
import '../../../../core/design_system/tokens/dealgo_tokens.dart';
import '../../../../core/motion/dealgo_motion_widgets.dart';
import '../../../../core/motion/dealgo_sheet.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../promotion/domain/entities/available_voucher.dart';
import '../../../promotion/domain/entities/voucher_quote.dart';
import '../../../promotion/domain/usecases/list_available_vouchers.dart';
import '../../../promotion/presentation/widgets/food_voucher_picker_sheet.dart';
import '../../domain/entities/food_money.dart';
import '../cubit/food_cart_cubit.dart';
import '../utils/food_routes.dart';
import 'food_widgets.dart';

/// Discovery voucher wall: the three most useful FOOD vouchers still on offer.
///
/// Hides on empty and on failure so the feed never waits on promotions; the
/// loading state is a one-row skeleton of the same height as the cards.
class FoodVoucherWall extends StatefulWidget {
  const FoodVoucherWall({super.key});

  @override
  State<FoodVoucherWall> createState() => _FoodVoucherWallState();
}

class _FoodVoucherWallState extends State<FoodVoucherWall> {
  static const _maxVouchers = 3;

  List<AvailableVoucher>? _vouchers;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final token = currentAccessToken(context);
    if (token == null) {
      setState(() => _vouchers = const []);
      return;
    }
    try {
      final available = await context.read<ListAvailableVouchers>()(
        accessToken: token,
        service: VoucherService.food,
      );
      if (!mounted) {
        return;
      }
      final now = DateTime.now();
      final usable = [
        for (final voucher in available)
          if (voucher.usesLeft > 0 &&
              voucher.endsAt.isAfter(now) &&
              (voucher.service == null ||
                  voucher.service == VoucherService.food))
            voucher,
      ];
      setState(() {
        _vouchers = usable.take(_maxVouchers).toList(growable: false);
      });
    } on Object {
      if (mounted) {
        setState(() => _vouchers = const []);
      }
    }
  }

  Future<void> _openList() async {
    final token = currentAccessToken(context);
    if (token == null) {
      return;
    }
    final cart = context.read<FoodCartCubit>();
    final vouchers = context.read<ListAvailableVouchers>();
    if (cart.state.lines.isEmpty) {
      await context.push(FoodRoutes.vouchers);
      return;
    }
    final code = await showDealGoSheet<String>(
      context: context,
      isScrollControlled: true,
      builder: (context) => FoodVoucherPickerSheet(
        selectedCode: cart.state.voucherCode,
        orderAmountVnd: cart.state.subtotalVnd,
        deliveryFeeVnd: cart.state.offeredDeliveryFareVnd ?? 0,
        load: () => vouchers(
          accessToken: token,
          service: VoucherService.food,
        ),
      ),
    );
    if (!mounted || code == null || code.isEmpty) {
      return;
    }
    cart.applyVoucher(code: code);
  }

  @override
  Widget build(BuildContext context) {
    final vouchers = _vouchers;
    if (vouchers != null && vouchers.isEmpty) {
      return const SizedBox.shrink();
    }
    final l10n = AppLocalizations.of(context);
    return Column(
      key: const Key('food-voucher-wall'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _WallHeader(
          title: l10n.foodVoucherWallTitle,
          seeAll: l10n.foodVoucherWallSeeAll,
          onSeeAll: _openList,
        ),
        const SizedBox(height: DealGoSpacing.s12),
        if (vouchers == null)
          const _WallSkeleton()
        else
          SizedBox(
            height: 132,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              clipBehavior: Clip.none,
              itemCount: vouchers.length,
              separatorBuilder: (_, _) =>
                  const SizedBox(width: DealGoSpacing.s12),
              itemBuilder: (context, index) {
                final voucher = vouchers[index];
                return DealGoStaggerIn(
                  index: index,
                  child: SizedBox(
                    width: 286,
                    child: _VoucherTicket(
                      voucher: voucher,
                      onTap: _openList,
                    ),
                  ),
                );
              },
            ),
          ),
        const SizedBox(height: DealGoSpacing.s16),
      ],
    );
  }
}

class _WallHeader extends StatelessWidget {
  const _WallHeader({
    required this.title,
    required this.seeAll,
    required this.onSeeAll,
  });

  final String title;
  final String seeAll;
  final VoidCallback onSeeAll;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Row(
      children: [
        Expanded(child: Text(title, style: textTheme.titleMedium)),
        TextButton(
          key: const Key('food-voucher-wall-see-all'),
          onPressed: onSeeAll,
          style: TextButton.styleFrom(
            foregroundColor: DealGoColors.primary,
            padding: const EdgeInsets.symmetric(horizontal: DealGoSpacing.s8),
            minimumSize: Size.zero,
            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          ),
          child: Text(seeAll),
        ),
      ],
    );
  }
}

class _VoucherTicket extends StatelessWidget {
  const _VoucherTicket({required this.voucher, required this.onTap});

  final AvailableVoucher voucher;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final locale = Localizations.localeOf(context).toLanguageTag();
    final cap = voucher.maxDiscountVnd;
    return DealGoVoucherTicket(
      tapKey: Key('food-voucher-${voucher.code}'),
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
      ],
      onTap: onTap,
    );
  }
}

class _WallSkeleton extends StatelessWidget {
  const _WallSkeleton();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 132,
      child: DealGoShimmer(
        child: Row(
          children: [
            SizedBox(
              width: 286,
              child: Material(
                color: DealGoColors.card,
                child: const Padding(
                  padding: EdgeInsets.all(DealGoSpacing.s12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      DealGoSkeletonBox(width: 120, height: 18),
                      SizedBox(height: DealGoSpacing.s8),
                      DealGoSkeletonBox(width: 180, height: 12),
                      SizedBox(height: DealGoSpacing.s8),
                      DealGoSkeletonBox(width: 140, height: 12),
                    ],
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
