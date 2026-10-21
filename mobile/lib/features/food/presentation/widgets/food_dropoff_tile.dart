import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/design_system/icons/dealgo_icons.dart';
import '../../../../core/design_system/tokens/dealgo_tokens.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../identity/domain/entities/auth_state.dart';
import '../../../identity/presentation/cubit/auth_cubit.dart';
import '../../../places/presentation/place_picker_page.dart';
import '../../../pricing/domain/pricing.dart';
import '../cubit/food_cart_cubit.dart';

/// Delivery address row: opens the place picker and keeps the cart's
/// delivery fee quoted by the server for the current store and address.
class FoodDropoffTile extends StatefulWidget {
  const FoodDropoffTile({this.enabled = true, super.key});

  /// False once an order attempt is held, so the address cannot change.
  final bool enabled;

  @override
  State<FoodDropoffTile> createState() => _FoodDropoffTileState();
}

class _FoodDropoffTileState extends State<FoodDropoffTile> {
  var _quoting = false;
  var _failed = false;
  String? _quotedFor;

  @override
  void initState() {
    super.initState();
    _maybeQuote(context.read<FoodCartCubit>().state);
  }

  String? _quoteKey(FoodCartState cart) {
    final storeId = cart.storeId;
    if (storeId == null || !cart.hasDropoff || cart.deliveryFareVnd != null) {
      return null;
    }
    return '$storeId|${cart.dropoffLat}|${cart.dropoffLng}';
  }

  void _maybeQuote(FoodCartState cart) {
    final key = _quoteKey(cart);
    if (key == null || key == _quotedFor) {
      return;
    }
    _quotedFor = key;
    unawaited(_quote(cart));
  }

  Future<void> _quote(FoodCartState cart) async {
    final auth = context.read<AuthCubit>().state;
    final token = auth is AuthSignedIn ? auth.tokens.accessToken : null;
    final storeId = cart.storeId;
    if (token == null || storeId == null || !cart.hasDropoff) {
      return;
    }
    setState(() {
      _quoting = true;
      _failed = false;
    });
    final pricing = context.read<PricingRepository>();
    final cubit = context.read<FoodCartCubit>();
    try {
      final fare = await pricing.quoteFoodDelivery(
        accessToken: token,
        storeId: storeId,
        dropoff: (
          lat: cart.dropoffLat!,
          lng: cart.dropoffLng!,
          label: cart.dropoffLabel,
        ),
      );
      if (!mounted) {
        return;
      }
      final now = cubit.state;
      // Ignore a late answer for an address or store that changed meanwhile.
      if (now.storeId == storeId &&
          now.dropoffLat == cart.dropoffLat &&
          now.dropoffLng == cart.dropoffLng) {
        cubit.setDeliveryFare(fare);
      }
      setState(() => _quoting = false);
    } catch (_) {
      if (mounted) {
        setState(() {
          _quoting = false;
          _failed = true;
          _quotedFor = null;
        });
      }
    }
  }

  Future<void> _pick() async {
    final cubit = context.read<FoodCartCubit>();
    final place = await pickPlace(context, PlacePickPurpose.delivery);
    if (place == null || !mounted) {
      return;
    }
    cubit.setDropoff(label: place.label, lat: place.lat, lng: place.lng);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final textTheme = Theme.of(context).textTheme;
    return BlocListener<FoodCartCubit, FoodCartState>(
      listener: (_, cart) => _maybeQuote(cart),
      child: BlocBuilder<FoodCartCubit, FoodCartState>(
        buildWhen: (a, b) =>
            a.dropoffLabel != b.dropoffLabel ||
            a.deliveryFareVnd != b.deliveryFareVnd,
        builder: (context, cart) {
          final chosen = cart.hasDropoff;
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              InkWell(
                key: const Key('food-dropoff-pick'),
                onTap: widget.enabled ? _pick : null,
                borderRadius: BorderRadius.circular(DealGoRadius.input),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    vertical: DealGoSpacing.s8,
                  ),
                  child: Row(
                    children: [
                      const Icon(DealGoIcons.pin, color: DealGoColors.primary),
                      const SizedBox(width: DealGoSpacing.s12),
                      Expanded(
                        child: Text(
                          chosen ? cart.dropoffLabel : l10n.foodDropoffChoose,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: textTheme.bodyMedium?.copyWith(
                            fontWeight: chosen
                                ? FontWeight.w700
                                : FontWeight.w400,
                            color: chosen
                                ? DealGoColors.text
                                : DealGoColors.textSecondary,
                          ),
                        ),
                      ),
                      if (widget.enabled)
                        Text(
                          chosen ? l10n.foodDropoffChange : '',
                          style: textTheme.labelMedium?.copyWith(
                            color: DealGoColors.primary,
                          ),
                        ),
                      if (widget.enabled && !chosen)
                        const Icon(
                          DealGoIcons.chevronRight,
                          color: DealGoColors.textSecondary,
                        ),
                    ],
                  ),
                ),
              ),
              if (_quoting)
                Text(l10n.foodFareQuoting, style: textTheme.bodySmall)
              else if (_failed)
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        l10n.foodFareQuoteError,
                        key: const Key('food-fare-error'),
                        style: textTheme.bodySmall?.copyWith(
                          color: DealGoColors.danger,
                        ),
                      ),
                    ),
                    TextButton(
                      onPressed: () => _maybeQuote(cart),
                      child: Text(l10n.actionRetry),
                    ),
                  ],
                ),
            ],
          );
        },
      ),
    );
  }
}
