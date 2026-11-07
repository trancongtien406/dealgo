import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/network/api_error_l10n.dart';
import '../../../../core/design_system/tokens/dealgo_tokens.dart';
import '../../../payment/domain/payment_models.dart';
import '../../../payment/presentation/payment_method_sheet.dart';
import '../../../payment/presentation/payment_status_page.dart';
import '../../domain/entities/food_models.dart';
import '../../domain/usecases/get_food_store.dart';
import '../../domain/usecases/place_food_order.dart';
import '../cubit/food_cart_cubit.dart';
import '../cubit/food_checkout_cubit.dart';
import '../widgets/food_checkout_widgets.dart';
import 'food_order_success_page.dart';
import '../utils/food_routes.dart';
import '../widgets/food_widgets.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../../core/design_system/components/dealgo_app_header.dart';

class FoodCheckoutPage extends StatelessWidget {
  const FoodCheckoutPage({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) => FoodCheckoutCubit(
        getFoodStore: context.read<GetFoodStore>(),
        placeFoodOrder: context.read<PlaceFoodOrder>(),
      ),
      child: const _FoodCheckoutView(),
    );
  }
}

class _FoodCheckoutView extends StatefulWidget {
  const _FoodCheckoutView();

  @override
  State<_FoodCheckoutView> createState() => _FoodCheckoutPageState();
}

class _FoodCheckoutPageState extends State<_FoodCheckoutView> {
  CheckoutPhase _phase = const CheckoutEditing();
  CheckoutHeldAttempt? _attempt;
  var _busy = false;
  PaymentMethodOption _payment = PaymentMethodOption.cash;

  Future<void> _submit({bool retry = false}) async {
    if (_busy) {
      return;
    }
    final token = currentAccessToken(context);
    if (token == null) {
      setState(() {
        _phase = CheckoutRejected(sessionExpiredMessage(context));
      });
      _announceRejection();
      return;
    }
    final cart = context.read<FoodCartCubit>();
    final snapshot = cart.state;
    final held = retry ? _attempt : null;
    if (held == null && !snapshot.canCheckout) {
      setState(() {
        _phase = CheckoutRejected(
          checkoutBlockingMessage(snapshot, AppLocalizations.of(context)) ??
              AppLocalizations.of(context).checkoutErrGeneric,
        );
      });
      _announceRejection();
      return;
    }
    final attempt =
        held ??
        CheckoutHeldAttempt.fromCart(
          snapshot,
          token,
          paymentMethod: _payment.code,
        );
    _attempt = attempt;
    setState(() {
      _busy = true;
      _phase = CheckoutSubmitting(attempt);
    });
    final checkout = context.read<FoodCheckoutCubit>();
    try {
      if (!retry) {
        final fresh = await checkout.loadStore(
          accessToken: token,
          storeId: attempt.request.storeId,
        );
        if (!mounted) {
          return;
        }
        if (foodCatalogPriceDrift(fresh, snapshot)) {
          final nextSubtotal = foodCatalogSubtotal(snapshot, fresh);
          setState(() {
            _busy = false;
            _phase = CheckoutRepriced(
              previousTotalVnd: attempt.previewTotalVnd,
              previousSubtotalVnd: attempt.subtotalVnd,
              nextTotalVnd: nextSubtotal + attempt.request.deliveryFareVnd,
              catalog: fresh,
            );
          });
          return;
        }
      }
      final order = await checkout.placeOrder(attempt.request);
      if (!mounted) {
        return;
      }
      cart.rotateIdempotencyKey();
      final differs =
          order.subtotalVnd != attempt.subtotalVnd ||
          order.deliveryFareVnd != attempt.request.deliveryFareVnd ||
          order.totalVnd != attempt.previewTotalVnd;
      if (!differs) {
        setState(() {
          _busy = false;
          _phase = CheckoutPlaced(order);
        });
        await _openSuccess(order, attempt);
        return;
      }
      setState(() {
        _busy = false;
        _phase = CheckoutRepriced(
          previousTotalVnd: attempt.previewTotalVnd,
          previousSubtotalVnd: attempt.subtotalVnd,
          nextTotalVnd: order.totalVnd,
          order: order,
        );
      });
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _busy = false;
        _phase = checkoutFailurePhase(
          error,
          attempt,
          AppLocalizations.of(context),
        );
      });
      _announceRejection();
    }
  }

  /// The rejection banner sits at the top of a scrolled receipt, so the user
  /// tapping "Đặt hàng" at the bottom never saw it and thought the button was
  /// dead. Surface it as a snackbar above the bottom bar as well.
  void _announceRejection() {
    final phase = _phase;
    if (!mounted || phase is! CheckoutRejected) return;
    ScaffoldMessenger.maybeOf(context)
      ?..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          key: const Key('food-checkout-rejected-snack'),
          content: Text(phase.message),
          behavior: SnackBarBehavior.floating,
        ),
      );
  }

  Future<void> _openSuccess(
    PlacedFoodOrder order,
    CheckoutHeldAttempt attempt,
  ) async {
    // QA C1/C2 — the order exists: drop the cart and replace the checkout
    // stack, so Back from success/tracking never lands on a stale checkout.
    final cart = context.read<FoodCartCubit>();
    final method = attempt.request.paymentMethod;
    if (method != null && method != cashMethodCode) {
      context.go(
        PaymentRoutes.location(
          entityType: 'FOOD_ORDER',
          entityId: order.id,
          startMethod: method,
        ),
      );
      cart.clearAfterOrder();
      return;
    }
    context.go(
      FoodRoutes.orderSuccess,
      extra: FoodOrderSuccessArgs(
        order: order,
        storeName: attempt.storeName,
        storeAddress: null,
      ),
    );
    cart.clearAfterOrder();
  }

  Future<void> _acceptReprice(CheckoutRepriced phase) async {
    final order = phase.order;
    if (order != null) {
      setState(() => _phase = CheckoutPlaced(order));
      if (!mounted) {
        return;
      }
      final attempt = _attempt;
      if (attempt != null) {
        await _openSuccess(order, attempt);
      } else {
        final cart = context.read<FoodCartCubit>();
        context.go(FoodRoutes.order(order.id));
        cart.clearAfterOrder();
      }
      return;
    }
    final catalog = phase.catalog;
    if (catalog == null) {
      return;
    }
    final cart = context.read<FoodCartCubit>();
    cart.applyCatalog(catalog);
    final next = cart.state;
    if (!next.canCheckout) {
      setState(() {
        final l10n = AppLocalizations.of(context);
        _phase = CheckoutRejected(
          next.lines.isNotEmpty && next.minOrderShortVnd > 0
              ? l10n.checkoutErrMinOrder
              : l10n.checkoutMenuChangedEmpty,
        );
      });
      _announceRejection();
      return;
    }
    final token = currentAccessToken(context);
    if (token == null) {
      setState(() => _phase = CheckoutRejected(sessionExpiredMessage(context)));
      _announceRejection();
      return;
    }
    _attempt = CheckoutHeldAttempt.fromCart(
      next,
      token,
      paymentMethod: _payment.code,
    );
    await _submit(retry: true);
  }

  @override
  Widget build(BuildContext context) {
    final phase = _phase;
    final submitting = phase is CheckoutSubmitting;
    final cart = context.watch<FoodCartCubit>().state;
    return PopScope(
      canPop: !submitting,
      child: Scaffold(
        backgroundColor: DealGoColors.canvas,
        // Not extendBody: the payment tile is the last body child and was
        // painted under the bottom bar, so taps hit the bar instead.
        body: SafeArea(
          bottom: false,
          child: Column(
            children: [
              DealGoAppHeader(
                title: switch (phase) {
                  CheckoutSubmitting() => AppLocalizations.of(
                    context,
                  ).checkoutTitleSubmitting,
                  CheckoutOffline() => AppLocalizations.of(
                    context,
                  ).checkoutTitleOffline,
                  CheckoutRepriced() => AppLocalizations.of(
                    context,
                  ).checkoutTitleRepriced,
                  _ => AppLocalizations.of(context).checkoutTitle,
                },
                onBack: submitting ? () {} : null,
              ),
              Expanded(
                child: CheckoutBody(
                  phase: phase,
                  paymentTile: phase is CheckoutEditing
                      ? PaymentMethodTile(
                          service: 'FOOD',
                          selected: _payment.code,
                          enabled: !_busy,
                          onChanged: (m) => setState(() => _payment = m),
                        )
                      : null,
                ),
              ),
            ],
          ),
        ),
        bottomNavigationBar: checkoutActionsVisible(phase, cart, busy: _busy)
            ? CheckoutActions(
                phase: phase,
                busy: _busy,
                onSubmit: _submit,
                onAccept: () {
                  if (phase is CheckoutRepriced) {
                    _acceptReprice(phase);
                  }
                },
                onRetry: () => _submit(retry: true),
              )
            : null,
      ),
    );
  }
}
