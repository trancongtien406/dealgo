import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/network/api_exception.dart';
import '../../../../core/design_system/components/dealgo_bottom_bar.dart';
import '../../../../core/design_system/components/dealgo_primary_button.dart';
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
import '../../../promotion/presentation/widgets/voucher_field.dart';
import '../cubit/food_cart_cubit.dart';
import 'food_widgets.dart';
import '../../../../core/design_system/icons/dealgo_icons.dart';

class CheckoutBody extends StatelessWidget {
  const CheckoutBody({required this.phase, super.key});

  final CheckoutPhase phase;

  @override
  Widget build(BuildContext context) {
    return switch (phase) {
      CheckoutSubmitting(:final attempt) => _SubmittingBody(attempt: attempt),
      CheckoutOffline(:final attempt) => _OfflineBody(attempt: attempt),
      final CheckoutRepriced repriced => _RepricedBody(phase: repriced),
      CheckoutPlaced(:final order) => _Receipt(order: order, placed: true),
      CheckoutRejected(:final message) => _Receipt(notice: message),
      CheckoutEditing() => const _Receipt(),
    };
  }
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
    final child = switch (phase) {
      CheckoutEditing() ||
      CheckoutRejected() => _PlaceButton(onSubmit: onSubmit),
      CheckoutOffline() => _OfflineButtons(onRetry: onRetry),
      CheckoutRepriced(:final nextTotalVnd) => _RepriceButtons(
        label: AppLocalizations.of(context)
            .checkoutAcceptTotal(formatVnd(nextTotalVnd)),
        onAccept: onAccept,
      ),
      _ => null,
    };
    if (child == null || busy && phase is! CheckoutOffline) {
      return const SizedBox.shrink();
    }
    return DealGoBottomBar(child: child);
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
    return Row(
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
    );
  }
}

class _RepriceButtons extends StatelessWidget {
  const _RepriceButtons({required this.label, required this.onAccept});

  final String label;
  final VoidCallback onAccept;

  @override
  Widget build(BuildContext context) {
    return Row(
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
    );
  }
}

void _leave(BuildContext context) {
  if (context.canPop()) {
    context.pop();
  }
}

class _Receipt extends StatelessWidget {
  const _Receipt({this.order, this.notice, this.placed = false});

  final PlacedFoodOrder? order;
  final String? notice;
  final bool placed;

  @override
  Widget build(BuildContext context) {
    final cart = context.watch<FoodCartCubit>().state;
    final subtotal = order?.subtotalVnd ?? cart.subtotalVnd;
    final delivery = order?.deliveryFareVnd ?? cart.deliveryFareVnd ?? 0;
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
              ),
          ];
    final shownLines = lines.isEmpty && order == null ? lines : lines;
    final textTheme = Theme.of(context).textTheme;
    final l10n = AppLocalizations.of(context);
    final profile = context.watch<AuthCubit>().state;
    final phone = profile is AuthSignedIn ? profile.profile.phone : null;
    final recipient = phone == null
        ? AppLocalizations.of(context).checkoutRecipient
        : formatDisplayPhone(phone);
    return ListView(
      padding: const EdgeInsets.fromLTRB(
        DealGoDimensions.pageGutter,
        DealGoSpacing.s8,
        DealGoDimensions.pageGutter,
        DealGoSpacing.s24,
      ),
      children: [
        if (notice != null) ...[
          FoodNote(message: notice!, tone: FoodNoteTone.danger),
          const SizedBox(height: DealGoSpacing.s16),
        ],
        FoodPanel(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                AppLocalizations.of(context).checkoutRecipientAddress,
                style: textTheme.titleMedium,
              ),
              const SizedBox(height: DealGoSpacing.s12),
              Row(
                children: [
                  const CircleAvatar(
                    radius: 20,
                    backgroundColor: DealGoColors.subtlePurple,
                    child: Icon(DealGoIcons.user, color: DealGoColors.primary),
                  ),
                  const SizedBox(width: DealGoSpacing.s12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          recipient,
                          style: textTheme.bodyMedium?.copyWith(
                            fontWeight: FontWeight.w700,
                            color: DealGoColors.text,
                          ),
                        ),
                        Text(cart.dropoffLabel, style: textTheme.bodySmall),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: DealGoSpacing.s16),
        FoodPanel(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                AppLocalizations.of(context).checkoutItems,
                style: textTheme.titleMedium,
              ),
              if ((cart.storeName ?? '').isNotEmpty) ...[
                const SizedBox(height: DealGoSpacing.s8),
                Text(
                  cart.storeName!,
                  style: textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: DealGoColors.text,
                  ),
                ),
              ],
              for (final line in shownLines)
                FoodLineSummary(
                  name: line.name,
                  quantity: line.quantity,
                  unitPriceVnd: line.unit,
                  lineTotalVnd: line.total,
                  options: line.options,
                ),
            ],
          ),
        ),
        if (order == null && !placed) ...[
          const SizedBox(height: DealGoSpacing.s16),
          FoodPanel(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(l10n.voucherLabel, style: textTheme.titleMedium),
                const SizedBox(height: DealGoSpacing.s12),
                VoucherField(
                  service: VoucherService.food,
                  orderAmountVnd: subtotal,
                  deliveryFeeVnd: delivery,
                  storeId: cart.storeId,
                  accessToken: () => currentAccessToken(context),
                  formatAmount: formatVnd,
                  initialCode: cart.voucherCode,
                  onQuote: (quote) =>
                      context.read<FoodCartCubit>().applyVoucher(
                        code: quote != null && quote.valid ? quote.code : null,
                        discountVnd: quote?.discountVnd ?? 0,
                      ),
                ),
              ],
            ),
          ),
        ],
        const SizedBox(height: DealGoSpacing.s16),
        FoodPanel(
          color: DealGoColors.subtlePurple,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                AppLocalizations.of(context).checkoutTotalSection,
                style: textTheme.titleMedium,
              ),
              const SizedBox(height: DealGoSpacing.s8),
              FoodMoneyRow(
                label: AppLocalizations.of(context).checkoutSubtotal,
                amount: formatVnd(subtotal),
              ),
              FoodMoneyRow(
                label: AppLocalizations.of(context).checkoutDeliveryFee,
                amount: formatVnd(delivery),
              ),
              FoodMoneyRow(
                label: AppLocalizations.of(context).checkoutDiscount,
                amount: discount > 0 ? '-${formatVnd(discount)}' : formatVnd(0),
              ),
              const Divider(height: 24),
              FoodMoneyRow(
                label: AppLocalizations.of(context).checkoutCodTotal,
                amount: formatVnd(total),
                emphasize: true,
              ),
            ],
          ),
        ),
        const SizedBox(height: DealGoSpacing.s16),
        FoodPanel(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                AppLocalizations.of(context).checkoutPayment,
                style: textTheme.titleMedium,
              ),
              const SizedBox(height: DealGoSpacing.s8),
              DecoratedBox(
                decoration: const BoxDecoration(
                  color: DealGoColors.amberSurface,
                  borderRadius: BorderRadius.all(Radius.circular(999)),
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: DealGoSpacing.s12,
                    vertical: DealGoSpacing.s4,
                  ),
                  child: Text(
                    AppLocalizations.of(context).checkoutCodUncollected,
                    style: const TextStyle(
                      color: DealGoColors.warning,
                      fontWeight: FontWeight.w700,
                      fontSize: 13,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: DealGoSpacing.s8),
              Text(
                placed
                    ? AppLocalizations.of(context).checkoutPlacedNote
                    : AppLocalizations.of(context).checkoutPayLaterNote,
                style: textTheme.bodySmall,
              ),
            ],
          ),
        ),
      ],
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
      padding: const EdgeInsets.all(DealGoDimensions.pageGutter),
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
              const DecoratedBox(
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
        const SizedBox(height: DealGoSpacing.s16),
        FoodNote(
          tone: FoodNoteTone.amber,
          message: AppLocalizations.of(context).checkoutLockedNote,
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
      padding: const EdgeInsets.all(DealGoDimensions.pageGutter),
      children: [
        const SizedBox(height: DealGoSpacing.s24),
        const Center(
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
        const SizedBox(height: DealGoSpacing.s16),
        FoodNote(
          tone: FoodNoteTone.amber,
          message: AppLocalizations.of(context).checkoutOfflineNote,
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
      padding: const EdgeInsets.all(DealGoDimensions.pageGutter),
      children: [
        const SizedBox(height: DealGoSpacing.s24),
        const Center(
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

  factory CheckoutHeldAttempt.fromCart(FoodCartState cart, String token) {
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
            ),
        ],
        dropoff: FoodDropoff(
          lat: cart.dropoffLat!,
          lng: cart.dropoffLng!,
          label: cart.dropoffLabel.trim(),
        ),
        // Display quote only; the server recomputes the fee at placement.
        deliveryFareVnd: cart.deliveryFareVnd!,
        voucherCode: cart.voucherCode,
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
