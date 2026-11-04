import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/design_system/icons/dealgo_icons.dart';
import '../../../../core/design_system/tokens/dealgo_tokens.dart';
import '../../../../core/motion/dealgo_motion.dart';
import '../../../../core/motion/dealgo_motion_widgets.dart';
import '../../../../l10n/app_localizations.dart';
import '../../domain/entities/food_models.dart';
import '../../domain/entities/food_money.dart';
import '../cubit/food_cart_cubit.dart';
import '../utils/food_routes.dart';
import 'store_meta.dart';

/// Height a screen reserves under its scroll content for [FoodCartBar].
const double kFoodCartBarRoom = 88;

/// Floating cart on every food buying screen: item count, total, the saving
/// from the picked offer or what is still missing for the store's minimum
/// order, and "Xem giỏ hàng" to the checkout review. Slides in with the
/// first item and out when the cart empties; sits above the home indicator
/// or the role tab bar (`MediaQuery.padding.bottom`).
class FoodCartBar extends StatelessWidget {
  const FoodCartBar({this.storeId, this.offers = const [], super.key});

  /// Only show the cart of this store; null = whichever store it holds
  /// (lists and search), with the store name on the bar.
  final String? storeId;

  /// The store's live offers, to estimate the saving of a picked code
  /// before checkout prices it.
  final List<StoreOffer> offers;

  /// Whether the bar is on screen, so a page can leave room under its list.
  static bool showsFor(FoodCartState cart, {String? storeId}) =>
      cart.itemCount > 0 && (storeId == null || cart.storeId == storeId);

  @override
  Widget build(BuildContext context) {
    final cart = context.watch<FoodCartCubit>().state;
    final show = showsFor(cart, storeId: storeId);
    final bottom = MediaQuery.paddingOf(context).bottom;
    return DealGoSlideReveal(
      child: show
          ? Padding(
              key: const ValueKey('food-cart-bar-shown'),
              padding: EdgeInsets.fromLTRB(
                DealGoDimensions.pageGutter,
                DealGoSpacing.s8,
                DealGoDimensions.pageGutter,
                bottom + DealGoSpacing.s12,
              ),
              child: _Bar(
                cart: cart,
                offers: offers,
                showStore: storeId == null,
              ),
            )
          : null,
    );
  }
}

class _Bar extends StatelessWidget {
  const _Bar({
    required this.cart,
    required this.offers,
    required this.showStore,
  });

  final FoodCartState cart;
  final List<StoreOffer> offers;
  final bool showStore;

  int get _saving {
    if (cart.voucherDiscountVnd > 0) return cart.voucherDiscountVnd;
    final code = cart.voucherCode;
    if (code == null) return 0;
    for (final offer in offers) {
      if (offer.code == code) return storeOfferSaving(offer, cart.subtotalVnd);
    }
    return 0;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final textTheme = Theme.of(context).textTheme;
    final saving = _saving;
    final short = cart.minOrderShortVnd;
    final total = cart.subtotalVnd - saving;
    final storeName = cart.storeName?.trim() ?? '';
    // One status line, most useful first: what is missing, then the saving.
    final (String? note, Color noteColor) = short > 0
        ? (l10n.foodCartBarShortfall(formatVnd(short)), const Color(0xFFFFE3A3))
        : saving > 0
        ? (l10n.voucherSaveAmount(formatVnd(saving)), const Color(0xFFB8F5CF))
        : showStore && storeName.isNotEmpty
        ? (storeName, Colors.white70)
        : (null, Colors.white70);
    return Material(
      key: const Key('food-cart-bar'),
      color: DealGoColors.primary,
      elevation: 6,
      shadowColor: DealGoColors.primary.withValues(alpha: 0.4),
      borderRadius: BorderRadius.circular(DealGoRadius.card),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => context.push(FoodRoutes.checkout),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            DealGoSpacing.s12,
            DealGoSpacing.s12,
            DealGoSpacing.s12,
            DealGoSpacing.s12,
          ),
          child: Row(
            children: [
              _CartIcon(count: cart.itemCount),
              const SizedBox(width: DealGoSpacing.s12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Wrap(
                      crossAxisAlignment: WrapCrossAlignment.end,
                      spacing: DealGoSpacing.s6,
                      children: [
                        Text(
                          formatVnd(total < 0 ? 0 : total),
                          key: const Key('food-cart-bar-total'),
                          style: textTheme.titleMedium?.copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        if (saving > 0)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 2),
                            child: Text(
                              formatVnd(cart.subtotalVnd),
                              style: textTheme.labelSmall?.copyWith(
                                color: Colors.white70,
                                decoration: TextDecoration.lineThrough,
                                decorationColor: Colors.white70,
                              ),
                            ),
                          ),
                      ],
                    ),
                    if (note != null)
                      DealGoStatusSwitcher(
                        child: Text(
                          note,
                          key: ValueKey(note),
                          style: textTheme.labelMedium?.copyWith(
                            color: noteColor,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(width: DealGoSpacing.s8),
              DecoratedBox(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(DealGoRadius.pill),
                ),
                child: Padding(
                  key: const Key('food-cart-bar-open'),
                  padding: const EdgeInsets.symmetric(
                    horizontal: DealGoSpacing.s12,
                    vertical: DealGoSpacing.s8,
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        l10n.foodViewCart,
                        style: textTheme.labelLarge?.copyWith(
                          color: DealGoColors.primary,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(width: 2),
                      const Icon(
                        DealGoIcons.arrowRight,
                        size: 16,
                        color: DealGoColors.primary,
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CartIcon extends StatelessWidget {
  const _CartIcon({required this.count});

  final int count;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 44,
      height: 44,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.16),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              DealGoIcons.shoppingBag,
              color: Colors.white,
              size: 22,
            ),
          ),
          Positioned(
            right: -4,
            top: -4,
            child: AnimatedSwitcher(
              duration: DealGoMotion.durationFor(context, DealGoMotion.fast),
              transitionBuilder: (child, animation) =>
                  ScaleTransition(scale: animation, child: child),
              child: Container(
                key: ValueKey(count),
                constraints: const BoxConstraints(minWidth: 20),
                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                decoration: BoxDecoration(
                  color: DealGoColors.danger,
                  borderRadius: BorderRadius.circular(DealGoRadius.pill),
                  border: Border.all(color: DealGoColors.primary, width: 1.5),
                ),
                child: Text(
                  '$count',
                  key: const Key('food-cart-bar-count'),
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
