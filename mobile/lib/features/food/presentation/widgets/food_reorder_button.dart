import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/design_system/components/dealgo_dialog.dart';
import '../../../../core/design_system/components/dealgo_secondary_button.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../identity/domain/entities/auth_state.dart';
import '../../../identity/presentation/cubit/auth_cubit.dart';
import '../../domain/entities/food_models.dart';
import '../../domain/params/get_food_store_params.dart';
import '../../domain/usecases/get_food_store.dart';
import '../cubit/food_cart_cubit.dart';
import '../utils/food_routes.dart';

/// "Đặt lại": rebuilds the cart from a finished order against the live menu
/// (unavailable dishes are dropped), keeps the old address, and opens
/// checkout. The server quotes the fee and re-prices again at placement.
class FoodReorderButton extends StatefulWidget {
  const FoodReorderButton({required this.order, super.key});

  final FoodOrderDetail order;

  @override
  State<FoodReorderButton> createState() => _FoodReorderButtonState();
}

class _FoodReorderButtonState extends State<FoodReorderButton> {
  var _busy = false;

  Future<void> _reorder() async {
    final storeId = widget.order.storeId;
    if (storeId == null) {
      return;
    }
    final l10n = AppLocalizations.of(context);
    final ok = await showDealGoConfirmDialog(
      context: context,
      title: l10n.foodReorderConfirmTitle,
      body: l10n.foodReorderConfirmBody,
      confirmLabel: l10n.actionReorder,
      cancelLabel: l10n.actionCancel,
      confirmKey: const Key('food-reorder-confirm'),
    );
    if (!ok || !mounted) {
      return;
    }
    final auth = context.read<AuthCubit>().state;
    final token = auth is AuthSignedIn ? auth.tokens.accessToken : null;
    if (token == null) {
      return;
    }
    final messenger = ScaffoldMessenger.maybeOf(context);
    final cart = context.read<FoodCartCubit>();
    setState(() => _busy = true);
    try {
      final store = await context.read<GetFoodStore>()(
        GetFoodStoreParams(accessToken: token, storeId: storeId),
      );
      if (!mounted) {
        return;
      }
      final dropped = cart.reorder(widget.order, store);
      if (cart.state.lines.isEmpty) {
        setState(() => _busy = false);
        messenger?.showSnackBar(SnackBar(content: Text(l10n.foodReorderNone)));
        return;
      }
      final dropoff = widget.order.dropoff;
      cart.setDropoff(label: dropoff.label, lat: dropoff.lat, lng: dropoff.lng);
      if (dropped > 0) {
        messenger?.showSnackBar(
          SnackBar(content: Text(l10n.foodReorderPartial(dropped))),
        );
      }
      setState(() => _busy = false);
      await context.push(FoodRoutes.checkout);
    } catch (_) {
      if (!mounted) {
        return;
      }
      setState(() => _busy = false);
      messenger?.showSnackBar(SnackBar(content: Text(l10n.errorGeneric)));
    }
  }

  @override
  Widget build(BuildContext context) {
    return DealGoSecondaryButton(
      key: Key('food-reorder-${widget.order.id}'),
      label: AppLocalizations.of(context).actionReorder,
      enabled: !_busy && widget.order.storeId != null,
      onPressed: _reorder,
    );
  }
}
