import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/motion/dealgo_sheet.dart';
import '../../../../core/network/api_exception.dart';
import '../../../../core/design_system/components/dealgo_nav_insets.dart';
import '../../../../core/design_system/components/dealgo_bottom_bar.dart';
import '../../../../core/design_system/components/dealgo_primary_button.dart';
import '../../../../core/design_system/components/dealgo_profile_avatar.dart';
import '../../../../core/design_system/components/dealgo_secondary_button.dart';
import '../../../../core/design_system/tokens/dealgo_tokens.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../identity/domain/entities/auth_state.dart';
import '../../../identity/domain/phone_input.dart';
import '../../../identity/presentation/cubit/auth_cubit.dart';
import '../../domain/entities/food_models.dart';
import '../../domain/entities/food_money.dart';
import '../../domain/params/place_food_order_params.dart';
import '../../../promotion/domain/entities/voucher_quote.dart';
import '../../../promotion/domain/usecases/list_available_vouchers.dart';
import '../../../promotion/presentation/widgets/food_voucher_picker_sheet.dart';
import '../../../promotion/presentation/widgets/voucher_field.dart';
import '../cubit/food_cart_cubit.dart';
import 'food_checkout_extras.dart';
import 'food_dropoff_tile.dart';
import 'food_fare_widgets.dart';
import 'food_widgets.dart';
import 'food_badges.dart';
import '../utils/food_routes.dart';
import '../../../../core/design_system/components/dealgo_state_view.dart';
import '../../../../core/design_system/icons/dealgo_icons.dart';

class CheckoutBody extends StatelessWidget {
  const CheckoutBody({required this.phase, this.paymentTile, super.key});

  final CheckoutPhase phase;

  /// Method picker rendered inside the payment card while editing.
  final Widget? paymentTile;

  @override
  Widget build(BuildContext context) {
    return switch (phase) {
      CheckoutSubmitting(:final attempt) => _SubmittingBody(attempt: attempt),
      CheckoutOffline(:final attempt) => _OfflineBody(attempt: attempt),
      final CheckoutRepriced repriced => _RepricedBody(phase: repriced),
      CheckoutPlaced(:final order) => _Receipt(order: order, placed: true),
      CheckoutRejected(:final message) => _EditingOrEmpty(
        notice: message,
        paymentTile: paymentTile,
      ),
      CheckoutEditing() => _EditingOrEmpty(paymentTile: paymentTile),
    };
  }
}

/// Whether [phase] renders a sticky action bar. Kept in sync with
/// [CheckoutActions] so the page can omit the bar entirely instead of
/// rendering a zero-height one, which would drop the system inset from the
/// body's scroll padding.
bool checkoutActionsVisible(
  CheckoutPhase phase,
  FoodCartState cart, {
  required bool busy,
}) {
  if (busy && phase is! CheckoutOffline) return false;
  return switch (phase) {
    CheckoutEditing() || CheckoutRejected() => cart.lines.isNotEmpty,
    CheckoutOffline() || CheckoutRepriced() => true,
    _ => false,
  };
}

class CheckoutActions extends StatelessWidget {
  const CheckoutActions({
    required this.phase,
    required this.busy,
    required this.onSubmit,
    required this.onAccept,
    required this.onRetry,
    super.key,
  });

  final CheckoutPhase phase;
  final bool busy;
  final Future<void> Function({bool retry}) onSubmit;
  final VoidCallback onAccept;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final cart = context.watch<FoodCartCubit>().state;
    // Empty cart: CTA lives on DealGoStateView only (avoid duplicate bottom bar).
    final child = switch (phase) {
      CheckoutEditing() || CheckoutRejected() =>
        cart.lines.isEmpty ? null : _PlaceButton(onSubmit: onSubmit),
      CheckoutOffline() => _OfflineButtons(onRetry: onRetry),
      CheckoutRepriced(:final nextTotalVnd) => _RepriceButtons(
        label: AppLocalizations.of(context)
            .checkoutAcceptTotal(formatVnd(nextTotalVnd)),
        onAccept: onAccept,
      ),
      _ => null,
    };
    if (child == null || !checkoutActionsVisible(phase, cart, busy: busy)) {
      return const SizedBox.shrink();
    }
    return DealGoBottomBar(child: child);
  }
}

class _EditingOrEmpty extends StatelessWidget {
  const _EditingOrEmpty({this.notice, this.paymentTile});

  final String? notice;
  final Widget? paymentTile;

  @override
  Widget build(BuildContext context) {
    final cart = context.watch<FoodCartCubit>().state;
    if (cart.lines.isEmpty) {
      return _EmptyCheckoutBody(notice: notice);
    }
    return _Receipt(notice: notice, paymentTile: paymentTile);
  }
}

class _EmptyCheckoutBody extends StatelessWidget {
  const _EmptyCheckoutBody({this.notice});

  final String? notice;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return DealGoStateView(
      key: const Key('food-checkout-empty'),
      art: DealGoStateArt.noOrders,
      title: l10n.foodCartEmpty,
      message: notice ?? l10n.checkoutEmptyBody,
      actionLabel: l10n.checkoutBackToMenu,
      onAction: () => _backToMenu(context),
    );
  }
}

class _PlaceButton extends StatelessWidget {
  const _PlaceButton({required this.onSubmit});

  final Future<void> Function({bool retry}) onSubmit;

  @override
  Widget build(BuildContext context) {
    final cart = context.watch<FoodCartCubit>().state;
    return DealGoPrimaryButton(
      key: const Key('food-place-order'),
      label: AppLocalizations.of(context)
          .checkoutPlaceTotal(formatVnd(cart.previewTotalVnd)),
      trailingIcon: DealGoIcons.arrowRight,
      enabled: cart.canCheckout,
      onPressed: () => onSubmit(),
    );
  }
}

class _OfflineButtons extends StatelessWidget {
  const _OfflineButtons({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: DealGoSecondaryButton(
              label: AppLocalizations.of(context).checkoutBackToCart,
              onPressed: () => _leave(context),
            ),
          ),
          const SizedBox(width: DealGoSpacing.s12),
          Expanded(
            child: DealGoPrimaryButton(
              key: const Key('food-retry-order'),
              label: AppLocalizations.of(context).checkoutRetry,
              onPressed: onRetry,
            ),
          ),
        ],
      ),
    );
  }
}

class _RepriceButtons extends StatelessWidget {
  const _RepriceButtons({required this.label, required this.onAccept});

  final String label;
  final VoidCallback onAccept;

  @override
  Widget build(BuildContext context) {
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: DealGoSecondaryButton(
              label: AppLocalizations.of(context).checkoutBackToCartShort,
              onPressed: () => _leave(context),
            ),
          ),
          const SizedBox(width: DealGoSpacing.s12),
          Expanded(
            child: DealGoPrimaryButton(label: label, onPressed: onAccept),
          ),
        ],
      ),
    );
  }
}

void _leave(BuildContext context) {
  if (context.canPop()) {
    context.pop();
  }
}

void _backToMenu(BuildContext context) {
  final storeId = context.read<FoodCartCubit>().state.storeId;
  if (storeId != null && storeId.isNotEmpty) {
    context.go(FoodRoutes.store(storeId));
    return;
  }
  if (context.canPop()) {
    context.pop();
    return;
  }
  context.go('/customer/shop');
}

class _Receipt extends StatelessWidget {
  const _Receipt({
    this.order,
    this.notice,
    this.placed = false,
    this.paymentTile,
  });

  final PlacedFoodOrder? order;
  final String? notice;
  final bool placed;

  /// Method picker shown inside the payment card while the order is editable.
  final Widget? paymentTile;

  @override
  Widget build(BuildContext context) {
    final cart = context.watch<FoodCartCubit>().state;
    final subtotal = order?.subtotalVnd ?? cart.subtotalVnd;
    final delivery = order?.deliveryFareVnd ?? cart.offeredDeliveryFareVnd ?? 0;
    final total = order?.totalVnd ?? cart.previewTotalVnd;
    final discount = order?.discountVnd ?? cart.voucherDiscountVnd;
    final lines = order == null
        ? [
            for (final line in cart.lines)
              (
                name: line.name,
                quantity: line.quantity,
                unit: line.unitPriceVnd,
                total: line.lineTotalVnd,
                options: '',
                note: line.note,
                imageUrl: line.imageUrl,
              ),
          ]
        : [
            for (final line in order!.lines)
              (
                name: line.name,
                quantity: line.quantity,
                unit: line.unitPriceVnd,
                total: line.lineTotalVnd,
                options: line.optionsSummary,
                note: line.note,
                imageUrl: line.imageUrl,
              ),
          ];
    final textTheme = Theme.of(context).textTheme;
    final profile = context.watch<AuthCubit>().state;
    final recipient = checkoutRecipientLine(
      displayName: profile is AuthSignedIn ? profile.profile.displayName : null,
      phone: profile is AuthSignedIn ? profile.profile.phone : null,
      fallback: AppLocalizations.of(context).checkoutRecipient,
    );
    final itemCount = order == null
        ? cart.itemCount
        : order!.lines.fold<int>(0, (sum, line) => sum + line.quantity);
    final l10n = AppLocalizations.of(context);
    return ListView(
      key: const Key('food-checkout-scroll'),
      // The sticky CTA (Scaffold extendBody) sits over the list; its height
      // arrives as MediaQuery padding, so the last card scrolls clear of it.
      padding: dealGoScrollPadding(
        context,
        const EdgeInsets.fromLTRB(
          DealGoDimensions.pageGutter,
          DealGoSpacing.s8,
          DealGoDimensions.pageGutter,
          DealGoSpacing.s24,
        ),
      ),
      children: [
        if (notice != null) ...[
          FoodNote(message: notice!, tone: FoodNoteTone.danger),
          const SizedBox(height: DealGoSpacing.s12),
        ],
        _OrderStoreStrip(
          storeName: cart.storeName ?? '',
          itemCount: itemCount,
          etaMinutes: order == null && !placed ? cart.etaMinutes : null,
        ),
        const SizedBox(height: DealGoSpacing.s12),
        FoodPanel(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  DealGoProfileAvatar(
                    key: const Key('food-checkout-avatar'),
                    avatarUrl: accountAvatarUrl(profile),
                    size: 44,
                  ),
                  const SizedBox(width: DealGoSpacing.s12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          recipient,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.w700,
                            color: DealGoColors.text,
                          ),
                        ),
                        if (order != null || placed)
                          Text(
                            cart.dropoffLabel,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: textTheme.bodySmall,
                          ),
                      ],
                    ),
                  ),
                ],
              ),
              // Merged cart + checkout: the address (and its server-quoted
              // fee) is edited right here.
              if (order == null && !placed) ...[
                const Divider(height: DealGoSpacing.s24),
                const FoodDropoffTile(),
              ],
            ],
          ),
        ),
        if (order == null && !placed && cart.etaMinutes != null) ...[
          const SizedBox(height: DealGoSpacing.s12),
          FoodEtaLine(minutes: cart.etaMinutes!),
        ],
        if (order == null && !placed && cart.deliveryQuote != null) ...[
          const SizedBox(height: DealGoSpacing.s12),
          const FoodFareOfferPanel(),
        ],
        const SizedBox(height: DealGoSpacing.s12),
        FoodPanel(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      l10n.checkoutYourOrder,
                      style: textTheme.titleMedium,
                    ),
                  ),
                  FoodPill(
                    label: l10n.checkoutItemCount(itemCount),
                    foreground: DealGoColors.primary,
                    background: DealGoColors.subtlePurple,
                  ),
                ],
              ),
              const SizedBox(height: DealGoSpacing.s4),
              for (var i = 0; i < lines.length; i++) ...[
                if (i > 0) const Divider(height: 1),
                FoodLineSummary(
                  name: lines[i].name,
                  quantity: lines[i].quantity,
                  unitPriceVnd: lines[i].unit,
                  lineTotalVnd: lines[i].total,
                  options: lines[i].options,
                  note: lines[i].note,
                  imageUrl: lines[i].imageUrl,
                ),
              ],
            ],
          ),
        ),
        if (order == null && !placed) ...[
          const SizedBox(height: DealGoSpacing.s12),
          _CheckoutVoucherPanel(
            subtotal: subtotal,
            delivery: delivery,
            storeId: cart.storeId,
            initialCode: cart.voucherCode,
          ),
          const SizedBox(height: DealGoSpacing.s12),
          const FoodCheckoutExtrasPanel(),
        ],
        const SizedBox(height: DealGoSpacing.s12),
        _BillCard(
          subtotalVnd: subtotal,
          deliveryVnd: delivery,
          discountVnd: discount,
          totalVnd: total,
        ),
        const SizedBox(height: DealGoSpacing.s12),
        _PaymentCard(paymentTile: paymentTile, placed: placed),
      ],
    );
  }
}

class _OrderStoreStrip extends StatelessWidget {
  const _OrderStoreStrip({
    required this.storeName,
    required this.itemCount,
    this.etaMinutes,
  });

  final String storeName;
  final int itemCount;
  final int? etaMinutes;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final textTheme = Theme.of(context).textTheme;
    final name = storeName.trim();
    return FoodPanel(
      padding: const EdgeInsets.all(DealGoSpacing.s12),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: DealGoColors.subtlePurple,
              borderRadius: BorderRadius.circular(DealGoRadius.input),
            ),
            child: const Icon(
              DealGoIcons.store,
              size: 22,
              color: DealGoColors.primary,
            ),
          ),
          const SizedBox(width: DealGoSpacing.s12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name.isEmpty ? l10n.checkoutTitle : name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                    color: DealGoColors.text,
                  ),
                ),
                const SizedBox(height: DealGoSpacing.s2),
                Text(
                  [
                    l10n.checkoutItemCount(itemCount),
                    if (etaMinutes != null) l10n.checkoutEtaChip(etaMinutes!),
                  ].join(' · '),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: textTheme.bodySmall?.copyWith(
                    color: DealGoColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _BillCard extends StatelessWidget {
  const _BillCard({
    required this.subtotalVnd,
    required this.deliveryVnd,
    required this.discountVnd,
    required this.totalVnd,
  });

  final int subtotalVnd;
  final int deliveryVnd;
  final int discountVnd;
  final int totalVnd;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final textTheme = Theme.of(context).textTheme;
    return FoodPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(l10n.checkoutTotalSection, style: textTheme.titleMedium),
          const SizedBox(height: DealGoSpacing.s4),
          FoodMoneyRow(
            label: l10n.checkoutSubtotal,
            amount: formatVnd(subtotalVnd),
          ),
          FoodMoneyRow(
            label: l10n.checkoutDeliveryFee,
            amount: formatVnd(deliveryVnd),
          ),
          if (discountVnd > 0)
            FoodMoneyRow(
              label: l10n.checkoutDiscount,
              amount: '-${formatVnd(discountVnd)}',
            ),
          const Divider(height: DealGoSpacing.s24),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: Text(
                  l10n.checkoutCodTotal,
                  style: textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                    color: DealGoColors.text,
                  ),
                ),
              ),
              Text(
                formatVnd(totalVnd),
                key: const Key('food-checkout-total'),
                style: textTheme.headlineSmall?.copyWith(
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  color: DealGoColors.primary,
                ),
              ),
            ],
          ),
          if (discountVnd > 0) ...[
            const SizedBox(height: DealGoSpacing.s6),
            Row(
              children: [
                const Icon(
                  DealGoIcons.success,
                  size: 15,
                  color: DealGoColors.brandGreen,
                ),
                const SizedBox(width: DealGoSpacing.s4),
                Text(
                  l10n.checkoutYouSave(formatVnd(discountVnd)),
                  style: textTheme.bodySmall?.copyWith(
                    color: DealGoColors.brandGreen,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _PaymentCard extends StatelessWidget {
  const _PaymentCard({this.paymentTile, required this.placed});

  final Widget? paymentTile;
  final bool placed;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final textTheme = Theme.of(context).textTheme;
    final tile = paymentTile;
    return FoodPanel(
      key: const Key('food-checkout-payment'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(l10n.checkoutPayment, style: textTheme.titleMedium),
          const SizedBox(height: DealGoSpacing.s8),
          if (tile != null)
            tile
          else ...[
            FoodPill(
              label: l10n.checkoutCodUncollected,
              foreground: DealGoColors.warning,
              background: DealGoColors.amberSurface,
            ),
            const SizedBox(height: DealGoSpacing.s8),
            Text(
              placed ? l10n.checkoutPlacedNote : l10n.checkoutPayLaterNote,
              style: textTheme.bodySmall?.copyWith(
                color: DealGoColors.textSecondary,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _SubmittingBody extends StatelessWidget {
  const _SubmittingBody({required this.attempt});

  final CheckoutHeldAttempt attempt;

  @override
  Widget build(BuildContext context) {
    final preview = attempt.previewTotalVnd;
    return ListView(
      padding: dealGoScrollPadding(
        context,
        const EdgeInsets.all(DealGoDimensions.pageGutter),
      ),
      children: [
        const SizedBox(height: DealGoSpacing.s24),
        const Center(
          child: FoodStateIcon(
            icon: DealGoIcons.more,
            background: Color(0xFFE8F1FF),
            foreground: Color(0xFF2563EB),
          ),
        ),
        const SizedBox(height: DealGoSpacing.s16),
        Text(
          AppLocalizations.of(context).checkoutProcessingTitle,
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: DealGoSpacing.s8),
        Text(
          AppLocalizations.of(context).checkoutProcessingBody,
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.bodySmall,
        ),
        const SizedBox(height: DealGoSpacing.s16),
        FoodPanel(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                AppLocalizations.of(context).checkoutPendingRequest,
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: DealGoSpacing.s8),
              DecoratedBox(
                decoration: BoxDecoration(
                  color: DealGoColors.amberSurface,
                  borderRadius: BorderRadius.all(Radius.circular(999)),
                ),
                child: Padding(
                  padding: EdgeInsets.symmetric(
                    horizontal: DealGoSpacing.s8,
                    vertical: DealGoSpacing.s4,
                  ),
                  child: Text(
                    'PROCESSING',
                    style: TextStyle(
                      color: DealGoColors.warning,
                      fontWeight: FontWeight.w800,
                      fontSize: 12,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: DealGoSpacing.s12),
              FoodMoneyRow(
                label: AppLocalizations.of(context).checkoutCartRef,
                amount: _draftCode(attempt),
              ),
              FoodMoneyRow(
                label: AppLocalizations.of(context).checkoutExpectedAmount,
                amount: formatVnd(preview),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _OfflineBody extends StatelessWidget {
  const _OfflineBody({required this.attempt});

  final CheckoutHeldAttempt attempt;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: dealGoScrollPadding(
        context,
        const EdgeInsets.all(DealGoDimensions.pageGutter),
      ),
      children: [
        const SizedBox(height: DealGoSpacing.s24),
        Center(
          child: FoodStateIcon(
            icon: DealGoIcons.offline,
            background: DealGoColors.dangerSurface,
            foreground: DealGoColors.danger,
          ),
        ),
        const SizedBox(height: DealGoSpacing.s16),
        Text(
          AppLocalizations.of(context).checkoutOfflineTitle,
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: DealGoSpacing.s8),
        Text(
          AppLocalizations.of(context).checkoutOfflineBody,
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.bodySmall,
        ),
        const SizedBox(height: DealGoSpacing.s16),
        FoodPanel(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                AppLocalizations.of(context).checkoutUnsentCart,
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: DealGoSpacing.s8),
              FoodMoneyRow(
                label: AppLocalizations.of(context).checkoutCartRef,
                amount: _draftCode(attempt),
              ),
              FoodMoneyRow(
                label: AppLocalizations.of(context).checkoutExpectedTotal,
                amount: formatVnd(attempt.previewTotalVnd),
                emphasize: true,
              ),
              FoodMoneyRow(
                label: AppLocalizations.of(context).checkoutPayment,
                amount: AppLocalizations.of(context).checkoutCodShort,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _RepricedBody extends StatelessWidget {
  const _RepricedBody({required this.phase});

  final CheckoutRepriced phase;

  @override
  Widget build(BuildContext context) {
    final order = phase.order;
    final previousFare = phase.previousTotalVnd - phase.previousSubtotalVnd;
    final fareDelta = order == null ? 0 : order.deliveryFareVnd - previousFare;
    final serverSubtotal = order?.subtotalVnd;
    final serverDelivery = order?.deliveryFareVnd;
    final serverTotal = phase.nextTotalVnd;
    return ListView(
      padding: dealGoScrollPadding(
        context,
        const EdgeInsets.all(DealGoDimensions.pageGutter),
      ),
      children: [
        const SizedBox(height: DealGoSpacing.s24),
        Center(
          child: FoodStateIcon(
            icon: DealGoIcons.alert,
            background: DealGoColors.warningSurface,
            foreground: DealGoColors.warning,
          ),
        ),
        const SizedBox(height: DealGoSpacing.s16),
        Text(
          AppLocalizations.of(context).checkoutRepricedTitle,
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: DealGoSpacing.s8),
        Text(
          AppLocalizations.of(context).checkoutRepricedBody,
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.bodySmall,
        ),
        const SizedBox(height: DealGoSpacing.s16),
        FoodPanel(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                AppLocalizations.of(context).checkoutCompare,
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: DealGoSpacing.s8),
              FoodMoneyRow(
                label: AppLocalizations.of(context).checkoutPreviousTotal,
                amount: formatVnd(phase.previousTotalVnd),
              ),
              if (serverSubtotal != null)
                FoodMoneyRow(
                  label: AppLocalizations.of(context).checkoutSubtotal,
                  amount: formatVnd(serverSubtotal),
                ),
              if (serverDelivery != null && fareDelta != 0)
                FoodMoneyRow(
                  label: AppLocalizations.of(context).checkoutDeliveryIncrease,
                  amount: formatVndDelta(fareDelta),
                )
              else if (serverDelivery != null)
                FoodMoneyRow(
                  label: AppLocalizations.of(context).checkoutDeliveryFee,
                  amount: formatVnd(serverDelivery),
                ),
              FoodMoneyRow(
                label: AppLocalizations.of(context).checkoutNewTotal,
                amount: formatVnd(serverTotal),
                emphasize: true,
              ),
            ],
          ),
        ),
        const SizedBox(height: DealGoSpacing.s16),
        FoodNote(
          tone: FoodNoteTone.amber,
          message: order == null
              ? AppLocalizations.of(context).checkoutRepricedDraftNote
              : AppLocalizations.of(context).checkoutRepricedPlacedNote,
        ),
      ],
    );
  }
}

class CheckoutHeldAttempt {
  const CheckoutHeldAttempt({
    required this.request,
    required this.subtotalVnd,
    required this.previewTotalVnd,
    required this.storeName,
  });

  factory CheckoutHeldAttempt.fromCart(
    FoodCartState cart,
    String token, {
    String? paymentMethod,
  }) {
    final storeId = cart.storeId;
    if (storeId == null ||
        cart.dropoffLat == null ||
        cart.dropoffLng == null ||
        cart.deliveryFareVnd == null) {
      throw StateError('Cart is not ready for checkout');
    }
    return CheckoutHeldAttempt(
      subtotalVnd: cart.subtotalVnd,
      previewTotalVnd: cart.previewTotalVnd,
      storeName: cart.storeName ?? '',
      request: PlaceFoodRequest(
        accessToken: token,
        idempotencyKey: cart.idempotencyKey,
        storeId: storeId,
        items: [
          for (final line in cart.lines)
            FoodOrderItem(
              itemId: line.placeItemId,
              quantity: line.quantity,
              optionIds: line.optionIds,
              note: line.note,
            ),
        ],
        dropoff: FoodDropoff(
          lat: cart.dropoffLat!,
          lng: cart.dropoffLng!,
          label: cart.dropoffLabel.trim(),
        ),
        // The customer's offer (suggestion by default); the server checks
        // its bounds, and drivers accept or counter it after placement.
        deliveryFareVnd: cart.offeredDeliveryFareVnd!,
        deliveryOfferVnd: cart.deliveryQuote == null
            ? null
            : cart.offeredDeliveryFareVnd,
        voucherCode: cart.voucherCode,
        paymentMethod: paymentMethod,
        note: cart.note,
        utensils: cart.utensils,
      ),
    );
  }

  final PlaceFoodRequest request;
  final int subtotalVnd;
  final int previewTotalVnd;
  final String storeName;
}

int foodCatalogSubtotal(FoodCartState cart, FoodStoreDetail store) {
  final byId = {for (final item in store.items) item.id: item};
  var subtotal = 0;
  for (final line in cart.lines) {
    final item = byId[line.placeItemId];
    if (item != null && item.available) {
      final delta = foodOptionDelta(item.optionGroups, line.optionIds) ?? 0;
      subtotal += (item.priceVnd + delta) * line.quantity;
    }
  }
  return subtotal;
}

CheckoutPhase checkoutFailurePhase(
  Object error,
  CheckoutHeldAttempt attempt,
  AppLocalizations l10n,
) {
  if (_unreachable(error)) {
    return CheckoutOffline(attempt);
  }
  if (error is ApiException) {
    return CheckoutRejected(_messageFor(error, l10n));
  }
  return CheckoutOffline(attempt);
}

bool _unreachable(Object error) {
  if (error is ApiException) {
    return error.statusCode == 0 || error.errorCode == 'NETWORK_ERROR';
  }
  return true;
}

String _messageFor(ApiException error, AppLocalizations l10n) {
  final code = error.errorCode;
  if (code.startsWith('VOUCHER_')) {
    return l10n.checkoutVoucherRejected;
  }
  return switch (code) {
    'FOOD_ORDER_ALREADY_OPEN' => l10n.checkoutErrOrderOpen,
    'FOOD_ITEM_UNAVAILABLE' => l10n.checkoutErrItemUnavailable,
    'FOOD_DELIVERY_FARE_OUT_OF_RANGE' => l10n.checkoutErrFareRange,
    'FOOD_STORE_NOT_FOUND' => l10n.checkoutErrStoreNotFound,
    _ => l10n.checkoutErrGeneric,
  };
}

String _draftCode(CheckoutHeldAttempt attempt) {
  final raw = attempt.request.idempotencyKey.replaceAll(
    RegExp(r'[^A-Za-z0-9]'),
    '',
  );
  final tail = raw.length >= 3
      ? raw.substring(raw.length - 3).toUpperCase()
      : '014';
  return 'CART-$tail';
}

class _CheckoutVoucherPanel extends StatefulWidget {
  const _CheckoutVoucherPanel({
    required this.subtotal,
    required this.delivery,
    required this.storeId,
    required this.initialCode,
  });

  final int subtotal;
  final int delivery;
  final String? storeId;
  final String? initialCode;

  @override
  State<_CheckoutVoucherPanel> createState() => _CheckoutVoucherPanelState();
}

class _CheckoutVoucherPanelState extends State<_CheckoutVoucherPanel> {
  /// Code the field currently has quoted, mirrored from its callback: the
  /// field owns the truth, so clearing it there also clears the sheet's
  /// selected ticket on the next open.
  String? _appliedCode;
  String? _seededCode;
  var _seededVersion = 0;

  Future<void> _openList() async {
    final vouchers = context.read<ListAvailableVouchers>();
    final token = currentAccessToken(context);
    final code = await showDealGoSheet<String>(
      context: context,
      isScrollControlled: true,
      builder: (context) => FoodVoucherPickerSheet(
        orderAmountVnd: widget.subtotal,
        deliveryFeeVnd: widget.delivery,
        selectedCode: _appliedCode ?? widget.initialCode,
        load: () {
          if (token == null || token.isEmpty) {
            throw const ApiException(
              statusCode: 401,
              message: '',
              errorCode: 'UNAUTHORIZED',
            );
          }
          return vouchers(
            accessToken: token,
            service: VoucherService.food,
            storeId: widget.storeId,
          );
        },
      ),
    );
    if (!mounted || code == null || code.isEmpty) {
      return;
    }
    setState(() {
      _seededCode = code;
      _seededVersion++;
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final textTheme = Theme.of(context).textTheme;
    return FoodPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 32,
                height: 32,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: DealGoColors.subtlePurple,
                  borderRadius: BorderRadius.circular(DealGoRadius.input),
                ),
                child: const Icon(
                  DealGoIcons.voucher,
                  size: 17,
                  color: DealGoColors.primary,
                ),
              ),
              const SizedBox(width: DealGoSpacing.s8),
              Expanded(
                child: Text(l10n.voucherLabel, style: textTheme.titleMedium),
              ),
              TextButton(
                key: const Key('checkout-voucher-picker'),
                onPressed: _openList,
                style: TextButton.styleFrom(
                  minimumSize: const Size(0, 32),
                  padding: const EdgeInsets.symmetric(
                    horizontal: DealGoSpacing.s8,
                  ),
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                child: Text(l10n.accountVouchers),
              ),
            ],
          ),
          const SizedBox(height: DealGoSpacing.s8),
          VoucherField(
            service: VoucherService.food,
            orderAmountVnd: widget.subtotal,
            deliveryFeeVnd: widget.delivery,
            storeId: widget.storeId,
            accessToken: () => currentAccessToken(context),
            formatAmount: formatVnd,
            initialCode: widget.initialCode,
            seededCode: _seededCode,
            seededCodeVersion: _seededVersion,
            onQuote: (quote) {
              final applied = quote != null && quote.valid ? quote.code : null;
              if (applied != _appliedCode) {
                setState(() => _appliedCode = applied);
              }
              context.read<FoodCartCubit>().applyVoucher(
                code: applied,
                discountVnd: quote?.discountVnd ?? 0,
              );
            },
          ),
        ],
      ),
    );
  }
}

sealed class CheckoutPhase {
  const CheckoutPhase();
}

class CheckoutEditing extends CheckoutPhase {
  const CheckoutEditing();
}

class CheckoutSubmitting extends CheckoutPhase {
  const CheckoutSubmitting(this.attempt);

  final CheckoutHeldAttempt attempt;
}

class CheckoutOffline extends CheckoutPhase {
  const CheckoutOffline(this.attempt);

  final CheckoutHeldAttempt attempt;
}

class CheckoutRepriced extends CheckoutPhase {
  const CheckoutRepriced({
    required this.previousTotalVnd,
    required this.previousSubtotalVnd,
    required this.nextTotalVnd,
    this.order,
    this.catalog,
  });

  final int previousTotalVnd;
  final int previousSubtotalVnd;
  final int nextTotalVnd;
  final PlacedFoodOrder? order;
  final FoodStoreDetail? catalog;
}

class CheckoutPlaced extends CheckoutPhase {
  const CheckoutPlaced(this.order);

  final PlacedFoodOrder order;
}

class CheckoutRejected extends CheckoutPhase {
  const CheckoutRejected(this.message);

  final String message;
}

/// Recipient line on checkout: "Name · 0909 990 101" (name first, like the
/// delivery apps' address card); falls back to the phone, then the label.
String checkoutRecipientLine({
  required String? displayName,
  required String? phone,
  required String fallback,
}) {
  final name = displayName?.trim() ?? '';
  final shownPhone = (phone == null || phone.trim().isEmpty)
      ? null
      : formatDisplayPhone(phone);
  if (name.isNotEmpty && shownPhone != null) {
    return '$name · $shownPhone';
  }
  if (name.isNotEmpty) {
    return name;
  }
  return shownPhone ?? fallback;
}
