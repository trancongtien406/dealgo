import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/design_system/icons/dealgo_icons.dart';
import '../../../../core/design_system/tokens/dealgo_tokens.dart';
import '../../../../core/l10n/api_error_text.dart';
import '../../../../core/network/api_exception.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../identity/domain/entities/auth_state.dart';
import '../../../identity/presentation/cubit/auth_cubit.dart';
import '../../../places/presentation/current_place.dart';
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
  ApiException? _error;
  String? _quotedFor;

  @override
  void initState() {
    super.initState();
    final cart = context.read<FoodCartCubit>().state;
    _maybeQuote(cart);
    if (widget.enabled && !cart.hasDropoff) {
      // Smart default: deliver to where the customer is now.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          unawaited(_locateDefault());
        }
      });
    }
  }

  Future<void> _locateDefault() async {
    final auth = context.read<AuthCubit>().state;
    final token = auth is AuthSignedIn ? auth.tokens.accessToken : null;
    final cubit = context.read<FoodCartCubit>();
    try {
      final result = await locateCurrentPlace(context, accessToken: token)
          .timeout(
            const Duration(seconds: 8),
            onTimeout: () => const CurrentPlaceFailed(),
          );
      if (!mounted || cubit.state.hasDropoff) {
        return;
      }
      if (result is CurrentPlaceFound) {
        final place = result.place;
        cubit.setDropoff(label: place.label, lat: place.lat, lng: place.lng);
      }
    } catch (_) {
      // No location service (tests / denied): the customer picks manually.
    }
  }

  String? _quoteKey(FoodCartState cart) {
    final storeId = cart.storeId;
    if (storeId == null || !cart.hasDropoff || cart.deliveryQuote != null) {
      return null;
    }
    // A restored draft keeps the amount but not the offer bounds; re-quote so
    // checkout can offer the negotiation range instead of a frozen fee.
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
      _error = null;
    });
    final pricing = context.read<PricingRepository>();
    final cubit = context.read<FoodCartCubit>();
    try {
      final quote = await pricing.quoteFoodDelivery(
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
        cubit.setDeliveryQuote(quote);
      }
      setState(() => _quoting = false);
    } on ApiException catch (error) {
      if (mounted) {
        setState(() {
          _quoting = false;
          _error = error;
          _quotedFor = null;
        });
      }
    } catch (error) {
      if (mounted) {
        setState(() {
          _quoting = false;
          _error = ApiException(
            statusCode: 0,
            message: error.toString(),
            errorCode: 'NETWORK_ERROR',
          );
          _quotedFor = null;
        });
      }
    }
  }

  /// The two refusals that depend on where the customer is, not on the network.
  bool _tooFar(ApiException error) =>
      error.errorCode == 'FOOD_TOO_FAR' ||
      error.errorCode == 'FOOD_OUTSIDE_SERVICE_ZONE';

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
            a.deliveryFareVnd != b.deliveryFareVnd ||
            a.deliveryQuote != b.deliveryQuote,
        builder: (context, cart) {
          final chosen = cart.hasDropoff;
          final error = _error;
          final tooFar = error != null && _tooFar(error);
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              InkWell(
                key: const Key('food-dropoff-pick'),
                onTap: widget.enabled ? _pick : null,
                borderRadius: BorderRadius.circular(DealGoRadius.input),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    vertical: DealGoSpacing.s4,
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 32,
                        height: 32,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: DealGoColors.subtlePurple,
                          borderRadius: BorderRadius.circular(
                            DealGoRadius.input,
                          ),
                        ),
                        child: const Icon(
                          DealGoIcons.pin,
                          size: 17,
                          color: DealGoColors.primary,
                        ),
                      ),
                      const SizedBox(width: DealGoSpacing.s12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              l10n.foodDropoffTitle,
                              style: textTheme.labelSmall?.copyWith(
                                color: DealGoColors.textSecondary,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: DealGoSpacing.s2),
                            Text(
                              chosen
                                  ? cart.dropoffLabel
                                  : l10n.foodDropoffChoose,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: textTheme.bodyMedium?.copyWith(
                                fontWeight: chosen
                                    ? FontWeight.w700
                                    : FontWeight.w500,
                                color: chosen
                                    ? DealGoColors.text
                                    : DealGoColors.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ),
                      // The refusal keeps its own single action below, so the
                      // row does not repeat a second "Đổi" next to it.
                      if (widget.enabled && chosen && !tooFar) ...[
                        const SizedBox(width: DealGoSpacing.s8),
                        Text(
                          l10n.foodDropoffChange,
                          style: textTheme.labelMedium?.copyWith(
                            color: DealGoColors.primary,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                      if (widget.enabled && !chosen)
                        Icon(
                          DealGoIcons.chevronRight,
                          size: 18,
                          color: DealGoColors.textSecondary,
                        ),
                    ],
                  ),
                ),
              ),
              if (_quoting)
                Padding(
                  padding: const EdgeInsets.only(top: DealGoSpacing.s6),
                  child: Text(
                    l10n.foodFareQuoting,
                    style: textTheme.bodySmall?.copyWith(
                      color: DealGoColors.textSecondary,
                    ),
                  ),
                )
              else if (error != null)
                Padding(
                  padding: const EdgeInsets.only(top: DealGoSpacing.s8),
                  child: _FareProblem(
                    message: apiErrorText(l10n, error, report: false),
                    // Distance refusals only clear with a nearer address, so
                    // the fix is a new address rather than a retry.
                    actionLabel: tooFar
                        ? l10n.foodDropoffChangeAddress
                        : l10n.actionRetry,
                    actionKey: tooFar
                        ? const Key('food-fare-change-address')
                        : const Key('food-fare-retry'),
                    onAction: !widget.enabled
                        ? null
                        : tooFar
                        ? _pick
                        : () => _maybeQuote(cart),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}

class _FareProblem extends StatelessWidget {
  const _FareProblem({
    required this.message,
    required this.actionLabel,
    required this.actionKey,
    this.onAction,
  });

  final String message;
  final String actionLabel;
  final Key actionKey;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: DealGoColors.dangerSurface,
        borderRadius: BorderRadius.circular(DealGoRadius.input),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          DealGoSpacing.s12,
          DealGoSpacing.s8,
          DealGoSpacing.s4,
          DealGoSpacing.s8,
        ),
        child: Row(
          children: [
            const Icon(
              DealGoIcons.alert,
              size: 18,
              color: DealGoColors.danger,
            ),
            const SizedBox(width: DealGoSpacing.s8),
            Expanded(
              child: Text(
                message,
                key: const Key('food-fare-error'),
                style: textTheme.bodySmall?.copyWith(
                  color: DealGoColors.danger,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            if (onAction != null)
              TextButton(
                key: actionKey,
                onPressed: onAction,
                style: TextButton.styleFrom(
                  foregroundColor: DealGoColors.danger,
                  minimumSize: const Size(0, DealGoDimensions.minTapTarget),
                  padding: const EdgeInsets.symmetric(
                    horizontal: DealGoSpacing.s8,
                  ),
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                child: Text(actionLabel),
              ),
          ],
        ),
      ),
    );
  }
}
