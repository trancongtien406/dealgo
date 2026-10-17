import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/network/api_error_l10n.dart';
import '../../../../core/design_system/tokens/dealgo_tokens.dart';
import '../../domain/entities/food_models.dart';
import '../../domain/usecases/get_food_store.dart';
import '../../domain/usecases/place_food_order.dart';
import '../cubit/food_cart_cubit.dart';
import '../cubit/food_checkout_cubit.dart';
import '../widgets/food_checkout_widgets.dart';
import 'food_order_success_page.dart';
import '../utils/food_routes.dart';
import '../widgets/food_widgets.dart';

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

  Future<void> _submit({bool retry = false}) async {
    if (_busy) {
      return;
    }
    final token = currentAccessToken(context);
    if (token == null) {
      setState(() {
        _phase = CheckoutRejected(sessionExpiredMessage(context));
      });
      return;
    }
    final cart = context.read<FoodCartCubit>();
    final snapshot = cart.state;
    final held = retry ? _attempt : null;
    if (held == null && !snapshot.canCheckout) {
      return;
    }
    final attempt = held ?? CheckoutHeldAttempt.fromCart(snapshot, token);
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
        _phase = checkoutFailurePhase(error, attempt);
      });
    }
  }

  Future<void> _openSuccess(PlacedFoodOrder order, CheckoutHeldAttempt attempt) async {
    await context.push(
      FoodRoutes.orderSuccess,
      extra: FoodOrderSuccessArgs(
        order: order,
        storeName: attempt.storeName,
        storeAddress: '123 Lê Lợi, Hải Châu, Đà Nẵng',
      ),
    );
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
        await context.push(FoodRoutes.order(order.id));
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
        _phase = const CheckoutRejected(
          'Thực đơn vừa đổi và không còn món đã chọn.',
        );
      });
      return;
    }
    final token = currentAccessToken(context);
    if (token == null) {
      setState(
        () => _phase = CheckoutRejected(sessionExpiredMessage(context)),
      );
      return;
    }
    _attempt = CheckoutHeldAttempt.fromCart(next, token);
    await _submit(retry: true);
  }

  @override
  Widget build(BuildContext context) {
    final phase = _phase;
    final submitting = phase is CheckoutSubmitting;
    return PopScope(
      canPop: !submitting,
      child: Scaffold(
        backgroundColor: DealGoColors.canvas,
        body: SafeArea(
          bottom: false,
          child: Column(
            children: [
              FoodScreenHeader(
                title: switch (phase) {
                  CheckoutSubmitting() => 'Đang xác nhận đơn',
                  CheckoutOffline() => 'Thanh toán đơn hàng',
                  CheckoutRepriced() => 'Xác nhận lại giỏ hàng',
                  _ => 'Thanh toán đơn đồ ăn',
                },
                subtitle: switch (phase) {
                  CheckoutEditing() => null,
                  CheckoutPlaced() => null,
                  CheckoutRejected() => null,
                  _ => 'DealGo · Biến thể trạng thái',
                },
                onBack: submitting ? () {} : null,
              ),
              Expanded(child: CheckoutBody(phase: phase)),
            ],
          ),
        ),
        bottomNavigationBar: CheckoutActions(
          phase: phase,
          busy: _busy,
          onSubmit: _submit,
          onAccept: () {
            if (phase is CheckoutRepriced) {
              _acceptReprice(phase);
            }
          },
          onRetry: () => _submit(retry: true),
        ),
      ),
    );
  }
}
